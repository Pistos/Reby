require File.dirname(__FILE__) + '/../test_helper'
require 'player_controller'

# Re-raise errors caught by the controller.
class PlayerController; def rescue_action(e) raise e end; end

class PlayerControllerTest < Test::Unit::TestCase
  def setup
    @controller = PlayerController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
