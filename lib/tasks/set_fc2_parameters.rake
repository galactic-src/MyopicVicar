desc "set_fc2 parameter linkgaes for VLD files, dwelling, individuals and search records"
task :set_fc2_parameters, [:start, :finish, :search_records] => [:environment] do |t, args|
  require 'create_search_records_freecen2'

  file_for_messages = File.join(Rails.root, 'log/create fc2 parameter linkages.log')
  message_file = File.new(file_for_messages, 'w')
  start = args.start.to_i
  finish = args.finish.to_i
  search_record_creation = args.search_records.present? ? true : false
  p "Finish #{finish} must be greater than start #{start}" if start > finish
  crash if start > finish

  p "Producing report of creation of fc2 parameter linkages from VLDs starting at #{start} and an end of #{finish} with search record creation #{search_record_creation}"
  message_file.puts "Producing report of creation of fc2 parameter linkages from VLDs starting at #{start} and an end of #{finish} with search record creation #{search_record_creation}"
  @number = start - 1
  time_start = Time.now
  vld_files = Freecen1VldFile.all.order_by(_id: 1).compact
  max_files = vld_files.length
  finish = max_files if finish > max_files
  num = 0
  vld_files.each do |file|
    message_file.puts "File number #{num}, #{file.inspect}"
    num += 1
  end

  while @number < finish
    @number += 1
    p "#{@number} at #{Time.now}"

    file = vld_files[@number]
    message_file.puts "File number #{@number} is blank" if file.blank?
    next if file.blank?

    message_file.puts "Number #{@number} at #{Time.now} for file #{file.inspect}"
    freecen_piece = file.freecen_piece
    place = freecen_piece.place
    freecen2_piece = freecen_piece.freecen2_piece
    p "Missing Freecen2 piece for #{freecen_piece.inspect}" if freecen2_piece.blank?
    message_file.puts "Missing Freecen2 piece for #{freecen_piece.inspect}" if freecen2_piece.blank?
    next if freecen2_piece.blank?

    freecen2_district = freecen2_piece.freecen2_district
    freecen2_place = freecen2_piece.freecen2_place
    freecen2_piece.freecen1_vld_files = [file] unless freecen2_piece.freecen1_vld_files.include?(file)
    freecen2_district.freecen1_vld_files = [file] unless freecen2_district.freecen1_vld_files.include?(file)
    freecen2_place.freecen1_vld_files = [file] unless freecen2_district.freecen1_vld_files.include?(file) || freecen2_place.blank?
    freecen2_piece.save unless freecen2_piece.freecen1_vld_files.include?(file)
    freecen2_district.save unless freecen2_district.freecen1_vld_files.include?(file)
    freecen2_place.save unless freecen2_piece.freecen1_vld_files.include?(file) || freecen2_place.blank?
    message_file.puts "Missing Freecen2 place for #{freecen_piece.inspect}" if freecen2_place.blank?
    next if freecen2_place.blank?

    if freecen2_place.data_present == false
      freecen2_place.data_present = true
      place_save_needed = true
    end
    unless freecen2_place.cen_data_years.include?(freecen_piece.year)
      freecen2_place.cen_data_years << freecen_piece.year
      place_save_needed = true
    end
    freecen2_place.save! if place_save_needed

    if freecen_piece.status == 'Online'
      freecen2_piece.update_attributes(status: 'Online', status_date: file._id.generation_time.to_datetime.in_time_zone('London'))
    end
    p file
    p freecen2_place
    CreateSearchRecordsFreecen2.process(place, freecen2_place) if search_record_creation
  end
  time_end = Time.now
  finished = finish - start + 1
  seconds = (time_end - time_start).to_i
  average = seconds / finished
  p "Finished #{finished} files in #{seconds} second; average rate #{average}"
end
