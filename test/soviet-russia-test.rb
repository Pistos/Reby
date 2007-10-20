#!/usr/bin/env ruby

require 'test/unit'
require '../soviet-russia'

class TC_SovietRussia < Test::Unit::TestCase
    def test_inflect
        assert_equal( [ "beat", "beats" ], "beat".inflect )
        assert_equal( [ "eat", "eats" ], "eat".inflect )
        assert_equal( [ "swim", "swims" ], "swim".inflect )
        assert_equal( [ "test", "tests" ], "test".inflect )
    end
end