class FreeregContent
  include Mongoid::Document
  include Mongoid::Timestamps::Created::Short
  include Mongoid::Timestamps::Updated::Short

  require 'chapman_code'
  field :county, type: String#, :required => false
  field :chapman_codes,  type: Array, default: []
  validates_inclusion_of :county, :in => ChapmanCode::values+[nil]
  field :place, type: String
  field :church, type: String
  field :record_type, type: String#, :required => false
  field :place_ids, type: String
  attr_accessor :character
  attr_accessible :chapman_codes
  validates_inclusion_of :record_type, :in => RecordType::ALL_TYPES+[nil]
  validate :county_is_valid

  before_validation :clean_blanks

  def search
    Place.where(search_params).order_by(:place_name.asc).all

  end
  def search_params
    params = Hash.new
    params[:chapman_code] = county if county
    params
  end
  def get_alternate_place_names
    @names = Array.new
    @alternate_place_names = self.alternateplacenames.all
    @alternate_place_names.each do |acn|
      name = acn.alternate_name
      @names << name
    end
    @names
  end

  def county_is_valid
    if self.chapman_codes[0].nil?
      errors.add(:chapman_codes, "At least one county must be selected.")
    end
  end

  def place_ids_is_valid
    if self.place_ids.nil?
      errors.add(:place_ids, "At least one place must be selected. If there are none then there are no places transcribed")
    end
  end
  def clean_blanks
    chapman_codes.delete_if { |x| x.blank? }
  end
  def self.determine_if_selection_needed(chapman)
    result = false
    result = true if FreeregOptionsConstants::ALPHABET_SELECTION_LIST.include?(chapman)
    result
  end
  def self.get_header_information(chapman)
    page = Refinery::CountyPages::CountyPage.where(chapman_code: chapman).first
    page
  end
  def self.number_of_records_in_county(chapman)
    files = Freereg1CsvFile.county(chapman).all
    record = Array.new
    records = 0
    records_ma = 0
    records_ba = 0
    records_bu = 0
    files.each do |file|
      records = records.to_i + file.records.to_i unless file.records.nil?
      case file.record_type
      when "ba"
        records_ba = records_ba + file.records.to_i unless file.records.nil?
      when "ma"
        records_ma = records_ma + file.records.to_i unless file.records.nil?
      when "bu"
        records_bu = records_bu + file.records.to_i unless file.records.nil?
      end
    end
    record[0] = records
    record[1] = records_ba
    record[2] = records_bu
    record[3] = records_ma
    record
  end
  def self.get_records_for_display(chapman)
    places = Place.where(:chapman_code => chapman, :data_present => true, :disabled => 'false').all.order_by(place_name: 1) 
  end
  def self.get_places_for_display(chapman)
    places = Place.where(:chapman_code => chapman, :data_present => true,:disabled => 'false' ).all.order_by(place_name: 1)
    place_names = Array.new
    places.each do |place| 
     place_names << place.place_name
    end
    place_names
  end
  def self.check_how_to_proceed(parameter) 
    if parameter.nil?
     proceed = "no option"
    elsif parameter[:place].present? && parameter[:character].present?
      proceed = "dual"
    elsif parameter[:place].present?
      proceed = "place" 
    elsif parameter[:character].present?  
     proceed = "character"
    else
     proceed = "no option"
    end
  end
  def self.get_decades(files)
    decade = { }
    max = 1
    files.each_pair do |key,my_file|
      decade[key] = my_file["daterange"]
      if decade[key]
        if my_file["daterange"].length > max
          max = my_file["daterange"].length
        end
      end
    end
    decade["ba"] = Array.new(max, 0) unless decade["ba"]
    decade["bu"] = Array.new(max, 0) unless decade["bu"]
    decade["ma"] = Array.new(max, 0) unless decade["ma"]
    decade
  end
  def self.get_transcribers(files)
    transcriber = ["","",""]
    transcriber[0]= files["ba"]["transcriber_name"].join(', ').to_s  if files["ba"].present?
    transcriber[1]= files["ma"]["transcriber_name"].join(', ').to_s  if files["ma"].present?          
    transcriber[2]= files["bu"]["transcriber_name"].join(', ').to_s  if files["bu"].present?
    p transcriber
    transcriber
  end
end