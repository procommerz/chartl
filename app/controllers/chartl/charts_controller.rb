module Chartl
  class ChartsController < Chartl::ApplicationController
    # [GET]
    def show
      load_chart
      
      response.headers['X-Robots-Tag'] = 'noindex, nofollow'

      if request.format == 'csv'
        render text: CSV.generate { |csv| @chart.as_csv.each { |r| csv << r }}
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
  end
end