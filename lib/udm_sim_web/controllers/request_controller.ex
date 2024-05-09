defmodule UdmSimWeb.RequestController do
  use UdmSimWeb, :controller
  alias SessionManager

  def handle_soap_request(conn, _params) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    case Saxy.SimpleForm.parse_string(body) do

      {:ok, _body} ->
        case Map.get(XmlToMap.naive_map(body), "soapenv:Envelope") do

          %{"soapenv:Body" => body} ->
            handle_soap_body(body, conn)
          _ ->
            conn
              |> put_status(400)
              |> json("Invalid SOAP request")

          end

      {:error, _} ->
        conn
          |> put_status(400)
          |> json("Error parsing SOAP request")
    end
  end

  def handle_soap_request_session(conn, %{"session_id" => session_id}) do

  end

  defp handle_soap_body(soap_body, conn) do
    case Map.get(soap_body, "LGI") do
      %{} = lgi_data ->
        handle_lgi(lgi_data, conn)
      _ ->
        conn
          |> put_status(400)
          |> json("No valid operation key found in the soap body")
    end

  end

  defp handle_lgi(lgi_data, conn) do

    udm_username = Map.get(lgi_data, "OPNAME")
    udm_password = Map.get(lgi_data, "PWD")
    _resp =
      if udm_username == "udm_username" && udm_password == "udm_password" do
        case SessionManager.session_exists?(udm_username) do
          true ->
            session_data = GenServer.call(:sess_server, {:get_session, udm_username})
            if !is_session_expired(session_data) do
              IO.inspect("Session exist and not yet expired")
                SessionManager.update_session_timestamp(udm_username) # Updating the timestamp
                session_id = Map.get(session_data, :sess_id)
                redirectURL = "http://localhost:4000/#{session_id}"




                responseXML =  "<soapenv:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">
                          <soapenv:Body>
                              <LGIResponse>
                                  <Result>
                                      <ResultCode>0</ResultCode>
                                      <ResultDesc>Operation is successful</ResultDesc>
                                  </Result>
                              </LGIResponse>
                          </soapenv:Body>
                      </soapenv:Envelope>"


                conn
                  |> put_resp_header("Content-Type", "application/xml")
                  |> put_resp_header("Location", redirectURL)
                  |> put_resp_header("Connection", "Keep-Alive")
                  |> Plug.Conn.send_resp(307, responseXML)
                  #|> IO.inspect
            else
              IO.inspect("Session exist and expired")
              SessionManager.remove_session(udm_username)

              timeout_responseXML = "<soapenv:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">
              <soapenv:Body>
                  <LGOResponse>
                      <Result>
                          <ResultCode>5004</ResultCode>
                          <ResultDesc>Session ID invalid or time out</ResultDesc>
                      </Result>
                  </LGOResponse>
              </soapenv:Body>
          </soapenv:Envelope>"

              conn

                  |> Plug.Conn.send_resp(200, timeout_responseXML)
            end
          false ->
            IO.inspect("No Session")
            session_id = SessionManager.generate_session_id()
            time_logged_in = :erlang.system_time(:second)
            SessionManager.save_session(udm_username, session_id, time_logged_in)
            redirectURL = "http://localhost:4000/#{session_id}"


            responseXML =  "<soapenv:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">
            <soapenv:Body>
                <LGIResponse>
                    <Result>
                        <ResultCode>0</ResultCode>
                        <ResultDesc>Operation is successful</ResultDesc>
                    </Result>
                </LGIResponse>
            </soapenv:Body>
        </soapenv:Envelope>"

            conn
                |> put_resp_header("Content-Type", "application/xml")
                |> put_resp_header("Location", redirectURL)
                |> put_resp_header("Connection", "Keep-Alive")
                |> Plug.Conn.send_resp(307, responseXML)
        end
      else

         responseFailedXML = "<soapenv:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">
            <soapenv:Body>
                <LGIResponse>
                    <Result>
                        <ResultCode>1018</ResultCode>
                        <ResultDesc>Username/Password doesn't match</ResultDesc>
                    </Result>
                </LGIResponse>
            </soapenv:Body>
        </soapenv:Envelope>"


        conn
          |> Plug.Conn.send_resp(200, responseFailedXML)
      end

  end
  def is_session_expired(session) do
    current_time = :erlang.system_time(:second)
    logged_time = Map.get(session, :time_logged_in)
    current_time - logged_time > 50
  end
end
