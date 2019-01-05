class CheckAndDeleteOrphanRecords

  def self.process(limit, sleep_time, fix)
    #The purpose of this clean up utility is to eliminate search records that are unconnected with an entry. Or an entry without a batch
    Mongoid.load!("#{Rails.root}/config/mongoid.yml")
    Mongoid.raise_not_found_error = false
    file_for_warning_messages = "log/check_and_delete_orphan_records.log"
    FileUtils.mkdir_p(File.dirname(file_for_warning_messages) )
    message_file = File.new(file_for_warning_messages, "w")
    records = 0
    orphans = 0
    time_start = Time.now
    SearchRecord.no_timeout.each do |record|
      records = records + 1
      break if records == limit
      if records == (records/100000)*10000
        p records
        time_diff = Time.now - time_start
        average = time_diff * 1000 / records
        p average
        sleep(sleep_time.to_i)
      end
      entry_id = record.freereg1_csv_entry_id
      entry = Freereg1CsvEntry.find(entry_id)
      if entry.nil?
        orphans = orphans + 1
        record.delete if fix.present?
      end
    end
    p records
    p orphans
    time_diff = Time.now - time_start
    average_record = time_diff * 1000 / records
    average_orphan = time_diff * 1000 / orphans unless orphans.zero?
    p average_record
    p average_orphan
  end
end
