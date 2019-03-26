module Chartl
  class ChartsController < Chartl::ApplicationController
    # [GET]
    def show
      load_chart
      chartl_arguments
      filter

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
      end
    end

    def chartl_arguments
      header_chart = @chart.series.first['data'].first
      ary_params = params.permit(header_chart.map(&:to_sym)).to_h
      @chartl_arguments = ((header_chart & ary_params.keys).map {|k| [k, ary_params[k]]}.to_h).map {|j, v| j == 'completed_at' ? [j, JSON.parse(v)] : [j, v]}.to_h || {}
    end

    def filter
      data = @chart.series.first['data']
      headers = data.first
      string_selector = ''
      if @chartl_arguments
        @chartl_arguments.each do |k, v|
          string_selector += " && " if @chartl_arguments.keys.first != k
          if v.is_a?(Array)
            string_selector += "DateTime.parse(k[#{headers.find_index(k)}]) >= DateTime.parse('#{v[0]}') && DateTime.parse(k[#{headers.find_index(k)}]) <= DateTime.parse('#{v[1]}')"
          else
            string_selector += "k[#{headers.find_index(k)}].to_s == '#{v}'"
          end
        end

        @chart.series.first['data'] = data.select.with_index do |k, index|
          index == 0 ? true : eval(string_selector)
        end
      end
    end
  end
end

# TODO
# Nueva columna para guardar la busqueda (jsonb)
#
# Show:
# * Comprobamos se pasan nuevos parametros:
#    - Si: Guardamos los nuevos parametros y se recalculan los datos
#    - No: Nada
# * Se muestra la grafica los datos guardados
#
# ?range_from=2019.01.01&range_to=2019.02.01&id=50799