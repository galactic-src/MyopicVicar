class FreecenCsvFileIncorporate

  def self.incorporate(file, owner)
    freecen_file = FreecenCsvFile.find_by(file_name: file.to_s, chapman_code: owner.to_s)
    county = County.chapman_code(owner.to_s).first
    message = "#{file} for #{owner} "
    success, messagea = incorporate_records(freecen_file)
    message += messagea
    if success
      UserMailer.incorporation_report(county.county_coordinator, message, file, owner).deliver_now
    else
      UserMailer.incorporation_report_failure(county.county_coordinator, message, file, owner).deliver_now
    end
  end

  def self.incorporate_records(freecen_file)
    enumeration_districts = {}
    begin
      freecen_file.freecen_csv_entries.each do |entry|
        enumeration_districts[entry.civil_parish] = [] if enumeration_districts[entry.civil_parish].blank?
        enumeration_districts[entry.civil_parish] << entry.enumeration_district unless enumeration_districts[entry.civil_parish].include?(entry.enumeration_district)
        entry.translate_individual
      end
      success = true
      message = 'success'
      freecen_file.update_attributes(incorporated: true, enumeration_districts: enumeration_districts, incorporation_lock: true,
                                     incorporated_date: DateTime.now.in_time_zone('London'))
    rescue Exception => msg
      success = false
      message = "#{msg}, #{msg.backtrace.inspect}"
    end
    [success, message]
  end
end
