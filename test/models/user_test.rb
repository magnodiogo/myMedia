require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "subscription tier helpers" do
    user = User.new(email: "test@example.com", password: "password")
    
    assert user.free_tier?
    assert_not user.paid_tier?
    
    user.subscription_tier = "paid_monthly"
    assert user.paid_tier?
    assert_not user.free_tier?

    user.subscription_tier = "paid_yearly"
    assert user.paid_tier?
    assert_not user.free_tier?
  end

  test "subscription tier validation" do
    user = User.new(email: "test@example.com", password: "password")
    
    user.subscription_tier = "invalid"
    assert_not user.valid?
    assert_includes user.errors[:subscription_tier], "is not included in the list"
    
    user.subscription_tier = "free"
    assert user.valid?
    
    user.subscription_tier = "paid_monthly"
    assert user.valid?

    user.subscription_tier = "paid_yearly"
    assert user.valid?
  end
end
