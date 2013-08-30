#######################################################################
# test_bm3_core.rb
#
# Test suite for the main library.
#######################################################################
require 'rubygems'
gem 'test-unit'
require 'test/unit'
require 'bm3-core'

class TC_BM3_Core < Test::Unit::TestCase
  test "version number is set to expected value" do
    assert_equal('0.0.6', BM3::VERSION)
  end
end
