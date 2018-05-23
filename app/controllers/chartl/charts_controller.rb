module Chartl
  class ChartsController < ApplicationController
    # [GET]
    def show
      if params[:id].to_i.to_s == params[:id].to_s
        @chart = Chartl::Chart.find(params[:id])
      else
        @chart = Chartl::Chart.find_by!(token: params[:id])
      end
    end

    def refresh
      # TODO
    end

    # POST
    def update
      # TODO
    end
  end
end