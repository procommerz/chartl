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

  def self.f(token)
    Chartl::Chart.find_by_token(token)
  end

  def self.build_with(code: , name: nil, type: 'chart', default_arguments: {})
    chart = Chartl::Chart.create { |c|
      c.data_code = code
      c.name = name
      c.options = { type: type.to_s, default_arguments: default_arguments }
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

  def update_code!(code)
    update!(data_code: code)
  end

  def user
    user_id ? user_class.find(user_id) : nil
  end

  def user_class
    @user_class ||= "Spree::User".constantize
  end

  def visual_type
    ((options && (options['type'] || options[:type])) || :chart).to_s
  end

  def refresh_data(save_series: true)
    result = nil

    eval_binding = binding

    arguments.each do |key, value|
      eval_binding.local_variable_set(key.to_sym, value)
    end

    ActiveRecord::Base.transaction do
      if visual_type == 'cohort'
        result = eval(self.data_code, eval_binding) # Hash format is required for the cohort
      else
        result = eval(self.data_code, eval_binding).to_a
      end

      raise ActiveRecord::Rollback, "Invalidate all changes" # to makesure nothing is actually changed by the code
    end

    # Transform basic one-series results into a series array
    if result.is_a?(Array) and result[0].is_a?(Array)
      result = [{'data' => result}]
    end

    if result && check_series(result)
      self.series = result

      if save_series
        self.update_columns(series: result, data_code: data_code, updated_at: Time.now)
        self.reload
      end
    else
      # TODO: Error exception or just db logging?
    end
  end

  def arguments=(args)
    @arguments = args
  end

  def arguments
    if default_arguments
      default_arguments.merge(@arguments || {})
    else
      @arguments || { "arg1" => nil, "arg2" => nil, "arg3" => nil, "args" => [], "range_from" => nil, "range_to" => nil }
    end
  end

  def default_arguments
    if options
      options["default_arguments"] || options[:default_arguments] || {}
    else
      {}
    end
  end

  def has_default_arguments?
    default_arguments.keys.any?
  end

  def has_user_arguments?
    (@arguments && @arguments.keys.any?) ? true : false
  end

  def has_user_argument?(key)
    (@arguments && @arguments.keys.include?(key.to_s)) ? true : false
  end

  def primary_data
    if visual_type == 'cohort'
      series
    else
      series[0]['data'] || series[0][:data]
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
    "#<Chartl::Chart:#{id} name=#{name} data_code=#{data_code.to_s[0..30].gsub("\n", "; ")}... url=#{get_link}>"
  end

  def as_csv
    csv_data = []

    if visual_type == 'chart'
      csv_data << ["Time"] + series.map { |s| s['name'] || s[:name] }

      hashes_of_data = series.map {|s| s['data'].to_h}
      csv_hash = {}

      # Generate hash with all "Timestaps" keys from  all hashes
      hashes_of_data.each{ |h|
        h.each_key { |k|
          csv_hash[k] = []
        }
      }

      # assign value from each "Timestaps" if present, othervise 0 (treat for missing data)
      csv_hash.each_key { |k|
        hashes_of_data.each{ |h|
          csv_hash[k].append(h[k] || 0)
        }
      }

      csv_data << csv_hash.sort.to_a
      csv_data = csv_data.flatten().each_slice(series.size+1).to_a

    elsif visual_type == 'table'
      csv_data = series[0]['data'] if series[0]
    end

    csv_data
  end

  private

  def check_series(series)
    if visual_type != 'cohort'
      raise "Not an array" if !series.is_a?(Array)

      series.each.with_index do |s, num|
        raise "Member #{num} in series not a hash" if !s.is_a?(Hash)
        raise "Member 'data' field invalid in series #{num}" if !s['data'].is_a?(Array) and !s[:data].is_a?(Array)
        # raise "Member 'type' field invalid. Possible values: spline, column, bar" if series[0]['type'].is_a?(String) and
      end

      true
    else
      # TODO: Cohort data validation?
      true
    end
  end

  def refresh_data_if_data_code_changed
    if data_code_changed? and !new_record?
      refresh_data
    end

    nil
  end
end