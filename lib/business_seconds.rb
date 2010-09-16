class BusinessSeconds
  
  #Create a business seconds calculator initialized with a config that says what they business hours are and also what holidays there are.
  #Weekends are not configurable
  def initialize(config)
    business_day_start_string = config['business_day_starts']
    business_day_end_string = config['business_day_ends']
    @holidays = config['holidays']
    
    # @holidays.each do |holi|
    #   # puts "holiday config: " + holi.inspect
    #   holi.values.each do |hval|
    #     start_time = Time.parse(hval["start"])
    #     end_time = Time.parse(hval["end"])
    #     # puts "Start and End #{start_time} -- #{end_time}"
    #     if end_time <= start_time
    #       raise ArgumentError, "Can't have a holiday that ends before it begins #{holi.inspect}"
    #     end
    #     start_time_hour = (start_time - start_time.beginning_of_day)
    #     end_time_hour = (end_time - end_time.beginning_of_day)
    #     # puts "Start and End HOurs #{start_time_hour} -- #{end_time_hour}"
    #     if start_time.to_date != end_time.to_date && start_time_hour > end_time_hour
    #       raise ArgumentError, "Can't have a holiday span multiple days yet begin at an hour past it's ending hour. " +
    #                            "Please break this up into multiple holidays #{holi.inspect}"
    #     end
    #   end
    # end
    
    unless business_day_start_string && business_day_end_string
      raise ArgumentError, "Expected config to define business_day_starts and business_day_ends"
    end
    @business_day_starts = parse_seconds_from_time_string(business_day_start_string)
    @business_day_ends = parse_seconds_from_time_string(business_day_end_string)
  end
  
  #Calculate the day and time span given two dates (if a time zone is given it first converts them to that time zone)
  def calculate(from_time, to_time, time_zone)
    unless time_zone
      time_zone = from_time.zone
    end
    from = from_time.in_time_zone(time_zone)
    to = to_time.in_time_zone(time_zone)
    
    return business_days_and_seconds_from_date_range(from, to, time_zone)
  end
  
  def zero_hour_of_next_business_day(date, in_time_zone)
    date = date.advance_to_beginning_of_next_day
    while(business_hours_on_day(date, in_time_zone) == [0,0])
      date = date.advance_to_beginning_of_next_day
    end
    date
  end
  
  # Returns the Time at the end of the day +number_of_days_ago+.  
  # Currently only used for determining what the dividing day is for sending on the "You Case has been in Ready for Margin Marking for 3 days" email.
  def business_days_ago(number_of_days_ago, in_time_zone = "Eastern Time (US & Canada)")
    Time.use_zone(in_time_zone) do
      business_day_accumilator = 0
      real_days_ago = 0 # This includes the current day as the first day if it is not a weekend or holiday
      time_now = Time.now
      
      while true
        hours_on_day = business_hours_on_day(real_days_ago.days.ago, in_time_zone)
        business_day_accumilator += 1 unless hours_on_day[0] == 0 and hours_on_day[1] == 0
        
        break if business_day_accumilator == number_of_days_ago
        real_days_ago += 1
      end
      
      real_days_ago.days.ago.end_of_day
    end
  end
  
  
  private
  
  def find_holidays_on_date(date, in_time_zone)
    to_return = []
    @holidays.each do |holiday|
      value = holiday.values[0]
      holiday_start = parse_time_as_if_in_zone(value['start'], in_time_zone)
      holiday_end = parse_time_as_if_in_zone(value['end'], in_time_zone)
      # puts "holiday_start #{holiday_start} parsed from #{value['start']}"
      # puts "holiday_end #{holiday_end}  parsed from #{value['end']}"
      # puts "date #{date}"
      if date.to_date >= holiday_start.to_date && date.to_date <= holiday_end.to_date
        to_return << [holiday_start, holiday_end]
      end
    end
    to_return
  end
  
  def default_business_hours
    [@business_day_starts, @business_day_ends]
  end
  
  #given a day, return start and end of business hours on that day
  def business_hours_on_day(date, in_time_zone)
    # puts "in time zone #{in_time_zone}"
    date = date.in_time_zone(in_time_zone)
    weekends = [6,7]
    if weekends.include?(date.to_date.cwday)
      return [0,0]
    end
    holidays = find_holidays_on_date(date, in_time_zone)
    if holidays.empty?
      default_business_hours
    else
      # puts "default_business_hours: " + default_business_hours.inspect
      start_time, end_time = default_business_hours
      effective_start = start_time
      effective_end = end_time
      holidays.each do |holiday_start, holiday_end|
        # puts "holiday_start: #{holiday_start}"
        # puts "holiday_end: #{holiday_end}"
        
        if holiday_start.to_date < date.to_date
          holiday_start = date.to_date.beginning_of_day
        end
        if holiday_end.to_date > date.to_date
          holiday_end = date.to_date.end_of_day
        end
        
        # puts "determined holiday_start: #{holiday_start}"
        # puts "determined holiday_end: #{holiday_end}"        

        # puts "business begins: #{date.beginning_of_day + start_time}"
        # puts "business ends: #{date.beginning_of_day + end_time}"
        
        #if holiday starts before business and ends after business, return 0
        if holiday_start <= (date.beginning_of_day + start_time) && holiday_end >= (date.beginning_of_day + end_time)
          return [0,0]
        end
        #if holiday starts before business then set business day to start effectively when the holiday ends
        if holiday_start <= (date.beginning_of_day + start_time)
          # puts "holiday starts before business then set business day to start effectively when the holiday ends"
          # puts "holiday_end:" + holiday_end.inspect
          # puts "holiday_end.beginning_of_day:" + holiday_end.beginning_of_day.inspect
          
          seconds_for_holiday_end = seconds_from_day_start(holiday_end)
          if seconds_for_holiday_end > effective_start
            effective_start = seconds_for_holiday_end
          end
        end
        #if holiday ends after business then set business day to end effectively when the holiday start
        if holiday_end >= (date.beginning_of_day + end_time)
          # puts "holiday ends after business then set business day to end effectively when the holiday start"
          # puts "holiday_start:" + holiday_start.inspect
          # puts "holiday_start.beginning_of_day:" + holiday_start.beginning_of_day.inspect
          
          seconds_for_holiday_start = seconds_from_day_start(holiday_start)
          if seconds_for_holiday_start < effective_end
            effective_end = seconds_for_holiday_start
          end
        end
      end
      if effective_start > effective_end
        effective_start = effective_end
      end
      # puts "effective start and end " + [effective_start.to_i, effective_end.to_i].inspect
      [effective_start.to_i, effective_end.to_i]
    end
  end
  
  def business_seconds_for_hour_range(from, to, time_zone)
    business_hours = business_hours_on_day(from, time_zone)
    
    from_second = seconds_from_day_start(from)
    to_second = seconds_from_day_start(to)
    
    from_second_or_begining_of_day = (from_second > business_hours[0]) ? from_second : business_hours[0]
    # puts "from_second_or_begining_of_day: #{from_second_or_begining_of_day}"
    
    to_second_or_end_of_day = (to_second < business_hours[1]) ? to_second : business_hours[1]
    # puts "to_second_or_end_of_day: #{to_second_or_end_of_day}"
    
    total_seconds = to_second_or_end_of_day - from_second_or_begining_of_day
    if total_seconds < 0
      return 0
    else
      return total_seconds
    end
  end

  # # Original Implementation, that gives answers:
  # #
  #       begins after business hours one days and ends before business hours begin the next day
  #       time range Mon, 28 Apr 2008 17:16:25 EDT -- Tue, 29 Apr 2008 5:16:25 EDT
  #          0 days -- 0 seconds
  # 
  #       begins during business hours one days and ends before business hours begin the next day
  #       time range Mon, 28 Apr 2008 12:16:25 EDT -- Tue, 29 Apr 2008 5:16:25 EDT
  #          1 days -- 13415 seconds
  # 
  #       begins after business hour one day and ends during business hours the next day
  #       time range Mon, 28 Apr 2008 16:16:25 EDT -- Tue, 29 Apr 2008 9:16:25 EDT
  #          0 days -- 4585 seconds
  # 
  #       begings durings business hours one days and ends during business hours the next day
  #       time range Mon, 28 Apr 2008 12:16:25 EDT -- Tue, 29 Apr 2008 12:16:25 EDT
  #          1 days -- 28800 seconds
  #
  def business_days_and_seconds_from_date_range(from, to, time_zone)
    if(to < from)
      raise ArgumentError, "can't calculate negative time differences. Given from: #{from}, to: #{to}"
    end
    if(from + 30.years < to)
      raise ArgumentError, "range too large: From #{from} To #{to}"
    end
    if(from + 3.months < to)
      #range is so large that an approximate answer is good enough
      days = ((to - from) / 1.day) * 5 / 7
      seconds = days * 8.hours
      return [days, seconds]
    end
    
    if(from.to_date == to.to_date)
      return [0, business_seconds_for_hour_range(from, to, time_zone)]
    else
      days, seconds = business_days_and_seconds_from_date_range(from.advance_to_beginning_of_next_day, to, time_zone)
      seconds_to_add = business_seconds_for_hour_range(from, from.end_of_day, time_zone)
      # puts "Seconds to add #{seconds_to_add} on #{from.to_date.cwday}"
      if seconds_to_add > 0
        days += 1
        seconds += seconds_to_add
      end
      return [days, seconds]
    end
  end
  
  
  # # # Alternative Implementation, that gives different answers:
  # # # (1305 differences in 49 stats x 1291 cases ... 2.0629 % of stats affected, for dump of production made on 2008-11-19 )
  # # #
  # #     begins after business hours one days and ends before business hours begin the next day
  # #     time range Mon, 28 Apr 2008 17:16:25 EDT -- Tue, 29 Apr 2008 5:16:25 EDT
  # #        1 days -- 0 seconds
  # # 
  # #     begins during business hours one days and ends before business hours begin the next day
  # #     time range Mon, 28 Apr 2008 12:16:25 EDT -- Tue, 29 Apr 2008 5:16:25 EDT
  # #        1 days -- 13415 seconds
  # # 
  # #     begins after business hour one day and ends during business hours the next day
  # #     time range Mon, 28 Apr 2008 16:16:25 EDT -- Tue, 29 Apr 2008 9:16:25 EDT
  # #        1 days -- 4585 seconds
  # # 
  # #     begings durings business hours one days and ends during business hours the next day
  # #     time range Mon, 28 Apr 2008 12:16:25 EDT -- Tue, 29 Apr 2008 12:16:25 EDT
  # #        1 days -- 28800 seconds
  # #
  # def business_days_and_seconds_from_date_range(from, to, time_zone)
  #   if(to < from)
  #     raise ArgumentError, "can't calculate negative time differences. Given from: #{from}, to: #{to}"
  #   end
  #   if(from + 30.years < to)
  #     raise ArgumentError, "range too large: From #{from} To #{to}"
  #   end
  #   if(from + 3.months < to)
  #     #range is so large that an approximate answer is good enough
  #     days = ((to - from) / 1.day) * 5 / 7
  #     seconds = days * 8.hours
  #     return [days, seconds]
  #   end
  #   
  #   if(from.to_date == to.to_date)
  #     return [0, business_seconds_for_hour_range(from, to, time_zone)]
  #   else
  #     days, seconds = business_days_and_seconds_from_date_range(from.advance_to_beginning_of_next_day, to, time_zone)
  #     seconds_to_add = business_seconds_for_hour_range(from, from.end_of_day, time_zone)
  #     if business_seconds_for_hour_range(from.beginning_of_day, from.end_of_day, time_zone) > 0
  #       days += 1
  #     end
  #     # puts "Seconds to add #{seconds_to_add} on #{from.to_date.cwday}"
  #     if seconds_to_add > 0
  #       seconds += seconds_to_add
  #     end
  #     return [days, seconds]
  #   end
  # end

  def parse_time_as_if_in_zone(time_string, time_zone)    
    Time.use_zone(time_zone) do
      Time.zone.parse(time_string)
    end
  end
  
  def seconds_from_day_start(t)
    (t - t.beginning_of_day).to_i
  end
  
  def parse_seconds_from_time_string(t)
    seconds_from_day_start(Time.parse(t))
  end
  
  
end