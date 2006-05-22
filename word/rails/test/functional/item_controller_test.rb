require File.dirname(__FILE__) + '/../test_helper'
require 'item_controller'

# Re-raise errors caught by the controller.
class ItemController; def rescue_action(e) raise e end; end

class ItemControllerTest < Test::Unit::TestCase
  def setup
    @controller = ItemController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
