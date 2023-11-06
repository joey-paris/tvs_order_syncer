class Api::V1::PagesController < ApplicationController

def index
  render json: { "Status": "Forbidden" }, status: 403
end

end
