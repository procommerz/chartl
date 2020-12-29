class RefreshWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0, queue: :chartl

  def perform(token)
    @chart = Chartl::Chart.find_by!(token: token)
    @chart.refresh_data
  end
end
