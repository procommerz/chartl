class Chartl::Chart < ActiveRecord::Base
  before_create :generate_token
  before_save :refresh_data_if_data_code_changed
  after_create :refresh_data

  self.table_name = :chartl_charts

  def self.help
    puts ""
    puts "CHARTL is a fast way to create persisted and auto-updated charts from Ruby code via the IRB/Rails console."
    puts ""
    puts "Usage:"
    puts ""
    puts "Chartl::Chart.build_with(code: '" + "[{ data: User.where(\"created_at > ?\", 4.weeks.ago).group_by_day(:created_at).count.to_a }]".yellow + "')"
    puts ""
    puts "This will create a chart with pre-saved series data. The ruby code is also saved and can be eval'ed again later to update chart series data."
    puts "The code must always return an array of series hashes, like: [{...}, {...}, ...]. With each hash containing at least the 'data' key - an array of [time, value] pairs"
    # [{ yaxis: 0, name: "User Registrations by Hour", type: "spline", data: Spree::User.where("created_at > ?", 4.weeks.ago).group_by_day(:created_at).count.to_a }]
  end

  def self.build_with(code: , name: nil)
    chart = Chartl::Chart.create { |c|
      c.data_code = code
      c.name = name
    }

    chart.refresh_data
    chart.print_link

    chart
  end

  def get_link
    if Rails.env.development?
      "http://localhost:3000/chartl/charts/#{token}.html"
    elsif defined?(Rails::Console) and defined?(Settings) and Settings.try(:site_url)
      "#{Settings.site_url}/chartl/charts/#{token}.html"
    end
  end

  def print_link
    puts "View your chart at #{get_link}".green
  end

  def user
    user_id ? user_class.find(user_id) : nil
  end

  def user_class
    @user_class ||= "Spree::User".constantize
  end

  def refresh_data
    result = nil

    ActiveRecord::Base.transaction do
      result = eval(self.data_code).to_a
      raise ActiveRecord::Rollback, "Invalidate all changes" # to makesure nothing is actually changed by the code
    end

    # Transform basic one-series results into a series array
    if result.is_a?(Array) and result[0].is_a?(Array)
      result = [{'data' => result}]
    end

    if result and check_series(result)
      self.series = result
      self.update_columns(series: result, data_code: data_code)
      self.reload
    else
      # TODO: Error exception or just db logging?
    end
  end

  def test_data(override_code: nil)
    result = nil

    ActiveRecord::Base.transaction do
      result = eval(self.data_code)
      raise ActiveRecord::Rollback, "Invalidate all changes" # to makesure nothing is actually changed by the code
    end

    result
  end

  def generate_token
    self.token ||= begin
      chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".split('')
      token = ""
      24.times{ token << chars[rand(chars.size - 1)] }
      token
    end
  end

  def inspect
    "#<Chartl::Chart:#{id} name=#{name} data_code=#{data_code.to_s[0..30].gsub("\n", "; ")}...>"
  end

  def as_csv
    csv_data = []

    csv_data << ["Time"] + series.map { |s| s['name'] || s[:name] }

    # Find the longest series
    longest_series = series.sort_by { |s| (s['data'] || s[:data]).try(:size).to_i }.last

    (longest_series['data'] || longest_series[:data]).each.with_index { |row, num|
      csv_data << [row[0]] + series.map { |s| (s['data'] || s[:data])[num][1] }
    }

    csv_data
  end

  private

  def check_series(series)
    raise "Not an array" if !series.is_a?(Array)

    series.each.with_index do |s, num|
      raise "Member #{num} in series not a hash" if !s.is_a?(Hash)
      raise "Member 'data' field invalid in series #{num}" if !s['data'].is_a?(Array) and !s[:data].is_a?(Array)
      # raise "Member 'type' field invalid. Possible values: spline, column, bar" if series[0]['type'].is_a?(String) and
    end
  end

  def refresh_data_if_data_code_changed
    if data_code_changed? and !new_record?
      refresh_data
    end

    nil
  end
end