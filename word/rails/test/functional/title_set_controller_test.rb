require File.dirname(__FILE__) + '/../test_helper'
require 'title_set_controller'

# Re-raise errors caught by the controller.
class TitleSetController; def rescue_action(e) raise e end; end

class TitleSetControllerTest < Test::Unit::TestCase
  def setup
    @controller = TitleSetController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
