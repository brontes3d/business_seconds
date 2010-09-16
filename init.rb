$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'business_seconds'

#TODO: write a test for this with Sun, 04 Nov 2007 00:00:00 EDT -04:00 in_time_zone("Eastern Time (US & Canada)")
ActiveSupport::TimeWithZone.class_eval do
  def advance_to_beginning_of_next_day
    result = (self + 1.day).beginning_of_day
    if result.to_date == self.to_date
      (self + 1.hour).advance_to_beginning_of_next_day
    else
      result
    end
  end
end
