require 'test/unit'
require 'rubygems'
require 'active_support'

#require this plugin
require "#{File.dirname(__FILE__)}/../init"

class BusinessSecondsTest < Test::Unit::TestCase
  
  def config_without_holidays
    {
      'business_day_starts' => "9:00:00",
      'business_day_ends' => "17:00:00",
      'holidays' => []
    }
  end
  
  def config_with_holidays
    {
        "business_day_starts"=>"09:00:00", 
        "business_day_ends"=>"17:00:00", 
        "holidays"=>[
          {"thanksgiving_2008"=>{
              "start"=>"11/27/2008 00:00:00",
              "end"=>"11/28/2008 23:59:59"
          }}, 
          {"random_half_day_monday"=>{
              "start"=>"11/24/2008 00:00:00",
              "end"=>"11/24/2008 12:00:00"
          }}]
    }
  end
  
  def config_with_bleonard_comment_on_ticket_1838
    {
        "business_day_starts"=>"09:00:00", 
        "business_day_ends"=>"17:00:00", 
        "holidays"=>[
          {"fake_past_holiday_2008"=>{
              "start"=>"10/21/2008 12:00:00",
              "end"=>"10/21/2008 23:59:59"
          }}]
    }
  end
  
  def test_bleonard_comment_on_ticket_1838
    from_time = Time.parse("Tue Oct 21, 2008 at 12:00 PM UTC") #Tue, 21 Oct 2008 08:00:00 EDT
    to_time = Time.parse("Wed Oct 22, 2008 at 06:00 PM UTC") #Wed, 22 Oct 2008 14:00:00 EDT
    
    calculator = BusinessSeconds.new(config_with_bleonard_comment_on_ticket_1838)    
    days, seconds = calculator.calculate(from_time, to_time, "Eastern Time (US & Canada)")
    assert_equal(1, days)
    assert_equal(8.hours, seconds)
    
    calculator = BusinessSeconds.new(config_without_holidays)
    days, seconds = calculator.calculate(from_time, to_time, "Eastern Time (US & Canada)")    
    assert_equal(1, days)
    assert_equal(8.hours + 5.hours, seconds)
  end
  
  def test_other_bug_bleonard_comment_on_ticket_1838
    from_time = Time.parse("Tue Oct 21, 2008 at 12:00 PM UTC") #Tue, 21 Oct 2008 08:00:00 EDT
    to_time = Time.parse("Wed Oct 22, 2008 at 06:00 PM UTC") #Wed, 22 Oct 2008 14:00:00 EDT
    
    calculator = BusinessSeconds.new({
        "business_day_starts"=>"09:00:00", 
        "business_day_ends"=>"17:00:00", 
        "holidays"=>[
          {"fake_past_holiday_2008"=>{
              "start"=>"10/21/2008 13:00:00",
              "end"=>"10/22/2008 00:59:59"
          }}]
    })
    days, seconds = calculator.calculate(from_time, to_time, "Eastern Time (US & Canada)")
    assert_equal(1, days)
    assert_equal(9.hours, seconds)    
  end
  
  def test_with_holidays_alittleoff_see_ticket_1838
    from_time = Time.parse("Mon Oct 20, 2008 at 12:00 PM UTC")#Mon, 20 Oct 2008 08:00:00 EDT
    to_time = Time.parse("Wed Oct 22, 2008 at 06:00 PM UTC")#Wed, 22 Oct 2008 14:00:00 EDT
    
    calculator = BusinessSeconds.new(
      {
          "business_day_starts"=>"09:00:00", 
          "business_day_ends"=>"17:00:00", 
          "holidays"=>[
            {"my_birthday_is_a_holiday_a_little_off_2008"=>{
                "start"=>"10/20/2008 01:00:00",
                "end"=>"10/21/2008 01:59:59"
            }}]
      })    
    with_holiday_off_by_1_hour = calculator.calculate(from_time, to_time, "Eastern Time (US & Canada)")
    
    calculator = BusinessSeconds.new(
      {
          "business_day_starts"=>"09:00:00", 
          "business_day_ends"=>"17:00:00", 
          "holidays"=>[
            {"my_birthday_is_a_holiday_2008"=>{
                "start"=>"10/20/2008 00:00:00",
                "end"=>"10/20/2008 23:59:59"
            }}]
      })
    with_holiday_normal = calculator.calculate(from_time, to_time, "Eastern Time (US & Canada)")    
    
    assert_equal(with_holiday_normal, with_holiday_off_by_1_hour)
  end
  
  
  def test_without_holidays
    noon_the_friday_before = Time.parse("11/21/2008 12:00:00 -0500").utc
    late_the_monday_after = Time.parse("12/1/2008 20:00:00 -0500").utc
    calculator = BusinessSeconds.new(config_without_holidays)
    days, seconds = calculator.calculate(noon_the_friday_before, late_the_monday_after, "Eastern Time (US & Canada)")
    assert_equal(6, days)
    assert_equal(6 * 8.hours + 5.hours, seconds)
    assert_equal(190800, seconds)

    noon_the_friday_before = Time.parse("11/21/2008 12:00:00 +0300").utc
    late_the_monday_after = Time.parse("12/1/2008 20:00:00 +0300").utc
    calculator = BusinessSeconds.new(config_without_holidays)
    days, seconds = calculator.calculate(noon_the_friday_before, late_the_monday_after, "Moscow")
    assert_equal(6, days)
    assert_equal(6 * 8.hours + 5.hours, seconds)
    assert_equal(190800, seconds)

    noon_the_friday_before = Time.parse("11/21/2008 12:00:00 +0900").utc
    late_the_monday_after = Time.parse("12/1/2008 20:00:00 +0900").utc
    calculator = BusinessSeconds.new(config_without_holidays)
    days, seconds = calculator.calculate(noon_the_friday_before, late_the_monday_after, "Tokyo")
    assert_equal(6, days)
    assert_equal(6 * 8.hours + 5.hours, seconds)
    assert_equal(190800, seconds)
  end
  
  def test_business_hours_on_day
    BusinessSeconds.class_eval do
      def business_hours_on_day_public(*args)
        business_hours_on_day(*args)
      end
    end
    calculator = BusinessSeconds.new(config_with_holidays)
    
    assert_equal( [0, 0],
                  calculator.business_hours_on_day_public(Time.parse("11/27/2008 12:00:00 -0500"), "Eastern Time (US & Canada)"))
    assert_equal( [0, 0],
                  calculator.business_hours_on_day_public(Time.parse("11/28/2008 12:00:00 -0500"), "Eastern Time (US & Canada)"))
    assert_equal( [12.hours, 17.hours],
                  calculator.business_hours_on_day_public(Time.parse("11/24/2008 12:00:00 -0500"), "Eastern Time (US & Canada)"))
    
    assert_equal( [0, 0],
                  calculator.business_hours_on_day_public(Time.parse("11/27/2008 4:00:00 -0500").utc, "Nairobi"))
    assert_equal( [0, 0],
                  calculator.business_hours_on_day_public(Time.parse("11/28/2008 4:00:00 -0500").utc, "Nairobi"))
    assert_equal( [12.hours, 17.hours],
                  calculator.business_hours_on_day_public(Time.parse("11/24/2008 4:00:00 -0500").utc, "Nairobi"))
    
    assert_equal( [0, 0],
                  calculator.business_hours_on_day_public(Time.parse("11/26/2008 23:00:00 -0500").utc, "Hong Kong"))
    assert_equal( [0, 0],
                  calculator.business_hours_on_day_public(Time.parse("11/27/2008 23:00:00 -0500").utc, "Hong Kong"))
    assert_equal( [12.hours, 17.hours],
                  calculator.business_hours_on_day_public(Time.parse("11/23/2008 23:00:00 -0500").utc, "Hong Kong"))    
  end
  
  def test_with_holidays
    noon_the_friday_before = Time.parse("11/21/2008 12:00:00 -0500").utc
    late_the_monday_after = Time.parse("12/1/2008 20:00:00 -0500").utc
    calculator = BusinessSeconds.new(config_with_holidays)
    days, seconds = calculator.calculate(noon_the_friday_before, late_the_monday_after, "Eastern Time (US & Canada)")
    #days are friday nov 21, monday nov 24, tues nov 25, wed nov 26, monday dec 1st,  total of 5 days spanned = 4 bussiness days
    assert_equal(4, days)
    #5 full days, minus the 3 hours off on monday the 24th, minus the 3 hours not worked on fridy nov 21
    assert_equal(5 * 8.hours - 3.hours - 3.hours, seconds)
    assert_equal(122400, seconds)
    
    noon_the_friday_before = Time.parse("11/21/2008 12:00:00 +0300").utc
    late_the_monday_after = Time.parse("12/1/2008 20:00:00 +0300").utc
    calculator = BusinessSeconds.new(config_with_holidays)
    days, seconds = calculator.calculate(noon_the_friday_before, late_the_monday_after, "Moscow")
    #days are friday nov 21, monday nov 24, tues nov 25, wed nov 26, monday dec 1st,  total of 5 days spanned = 4 bussiness days
    assert_equal(4, days)
    #5 full days, minus the 3 hours off on monday the 24th, minus the 3 hours not worked on fridy nov 21
    assert_equal(5 * 8.hours - 3.hours - 3.hours, seconds)
    assert_equal(122400, seconds)
    
    noon_the_friday_before = Time.parse("11/21/2008 12:00:00 +0900").utc
    late_the_monday_after = Time.parse("12/1/2008 20:00:00 +0900").utc
    calculator = BusinessSeconds.new(config_with_holidays)
    days, seconds = calculator.calculate(noon_the_friday_before, late_the_monday_after, "Tokyo")
    #days are friday nov 21, monday nov 24, tues nov 25, wed nov 26, monday dec 1st,  total of 5 days spanned = 4 bussiness days
    assert_equal(4, days)
    #5 full days, minus the 3 hours off on monday the 24th, minus the 3 hours not worked on fridy nov 21
    assert_equal(5 * 8.hours - 3.hours - 3.hours, seconds)
    assert_equal(122400, seconds)
  end
    
end
