defmodule UdmSim.Repo do
  use Ecto.Repo,
    otp_app: :udm_sim,
    adapter: Ecto.Adapters.Postgres
end
