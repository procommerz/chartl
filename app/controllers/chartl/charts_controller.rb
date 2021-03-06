module Chartl
  class ChartsController < Chartl::ApplicationController
    # [GET]
    def show
      load_chart

      load_chart_arguments

      if custom_arguments_present?
        @chart.refresh_data(save_series: false)
      end

      response.headers['X-Robots-Tag'] = 'noindex, nofollow'

      if request.format == 'csv'
        separator = params[:csv_separator] || ","
        render text: CSV.generate(col_sep: separator) {|csv| @chart.as_csv.each {|r| csv << r}}
      else
        render_show
      end
    end

    # [GET]
    def refresh
      load_chart

      @chart.refresh_data

      render_show
    end

    # POST
    def update
      # TODO
    end

    def load_chart
      # Loading by ID won't work in production for security reasons
      if params[:id].to_i.to_s == params[:id].to_s and !Rails.env.production?
        @chart = Chartl::Chart.find(params[:id])
      else
        @chart = Chartl::Chart.find_by!(token: params[:id])
      end
    end

    def render_show
      if @chart.visual_type == 'chart'
        render :chart
      elsif @chart.visual_type == 'table'
        render :table
      elsif @chart.visual_type == 'cohort'
        render :cohort
      elsif @chart.visual_type == 'no_time_chart'
        render :no_time_chart
      end
    end

    def load_chart_arguments
      @arg_hash = {}

      @arg_hash["arg1"] = params[:arg1] if !params[:arg1].nil?
      @arg_hash["arg2"] = params[:arg2] if !params[:arg2].nil?
      @arg_hash["arg3"] = params[:arg3] if !params[:arg3].nil?

      @arg_hash["args"] = %w(arg1 arg2 arg3).map { |k| @arg_hash[k] }.compact if @arg_hash.keys.any? # put all 'argX' args into the 'args' key in sorted order

      @arg_hash["range_to"] = Time.parse(params[:range_to]) if !params[:range_to].blank?
      @arg_hash["range_from"] = Time.parse(params[:range_from]) if !params[:range_from].blank?


      if !@arg_hash.blank? && @chart
        @chart.arguments = @arg_hash
      end
    end

    def custom_arguments_present?
      @arg_hash.keys.any?
    end

    # def chartl_arguments
    #   header_chart = @chart.series.first['data'].first.reject{|k| k == 'id'}
    #   ary_params = params.permit(header_chart.map {|j, v| j.match(/.+_at$|.+At$/i) || j.match(/.+_time$|.+time$/i) || j.match(/date/i) || j.match(/when/i) ? {j.to_sym => []} : j.to_sym}).to_h
    #   if params[:form_filtered] && ary_params.empty?
    #     @chart.update_column(:url_params, {})
    #   end
    #   @chartl_arguments = if ary_params.empty?
    #                         @chart.url_params || {}
    #                       else
    #                         (header_chart & ary_params.keys).map do |k|
    #                           next if ary_params[k].is_a?(Array) && ary_params[k].any?(&:empty?)
    #                           [k, ary_params[k]]
    #                         end.compact.to_h
    #                       end
    # end
    #
    # def filter
    #   data = @chart.series.first['data']
    #   headers = data.first
    #   string_selector = ''
    #
    #   if !@chartl_arguments.empty?
    #     @chartl_arguments.each do |k, v|
    #       string_selector += " && " if @chartl_arguments.keys.first != k
    #       if v.is_a?(Array)
    #         string_selector += "DateTime.parse(k[#{headers.find_index(k)}]) >= DateTime.parse('#{v[0]}') && DateTime.parse(k[#{headers.find_index(k)}]) <= DateTime.parse('#{v[1]}')"
    #       else
    #         string_selector += "k[#{headers.find_index(k)}].to_s == '#{v}'"
    #       end
    #     end
    #     @chart.update_column(:url_params, @chartl_arguments)
    #     @chart.series.first['data'] = data.select.with_index {|k, index| index == 0 ? true : eval(string_selector)}
    #   end
    # end
  end
end
