class BestGuess < FreebmdDbBase
  self.pluralize_table_names = false
  self.table_name = 'BestGuess'
  has_one :best_guess_maariages, class_name: '::BestGuessMarriage', foreign_key: 'RecordNumber'
  has_one :best_guess_hash, class_name: '::BestGuessHash', foreign_key: 'RecordNumber'

  belongs_to :CountyCombos, foreign_key: 'CountyComboID', primary_key: 'CountyComboID', class_name: '::CountyCombo'
  has_many :ScanLinks, primary_key: 'ChunkNumber', foreign_key: 'ChunkNumber'
  has_many :best_guess_links, class_name: '::BestGuessLink', foreign_key: 'RecordNumber' #, primary_key: ['RecordNumber', 'AccessionNumber', 'SequenceNumber']
  extend SharedSearchMethods
  ENTRY_SYSTEM = 8
  ENTRY_REFERENCE = 512

  def friendly_url
    particles = []
    # first the primary names
    particles << self.GivenName if self.GivenName
    particles << self.Surname if self.Surname

    # then the record types
    particles << RecordType::display_name(self.RecordTypeID)
    # then county name
    county_code = self.CountyCombos.County if self.CountyCombos.present?
    particles << ChapmanCode.name_from_code(county_code) if county_code.present?
    # then location
    particles << self.District if self.District
    # then volume
    particles << "v#{self.Volume}" if self.Volume
    # then page
    particles << "p#{self.Page}" if self.Page
    friendly = particles.join('-')
    friendly.gsub!(/\W/, '-')
    friendly.gsub!(/-+/, '-')
    friendly.downcase!
  end

  def transcribers
    users = []
    #record_info = BestGuess.includes(:best_guess_links).where(RecordNumber: record).first
    self.best_guess_links.includes(:accession).each do |link|
      users << link.accession.bmd_file.submitter.UserID if self.Confirmed & ENTRY_SYSTEM || self.Confirmed & ENTRY_REFERENCE
    end
    users
    #record_info = BestGuess.where(RecordNumber: record).first
    #accession_numbers = BestGuessLink.where(RecordNumber: record).pluck(:AccessionNumber)
    #accessions = Accession.where(AccessionNumber: accession_numbers)
    #accessions_all = accessions# || accessions.where(SourceType: '+Z')
    #accession_files = accessions_all.pluck(:FileNumber)
    #file_submitters =  BmdFile.where(FileNumber: accession_files).pluck(:SubmitterNumber)
    #@transcribers = Submitter.where(SubmitterNumber: file_submitters).pluck(:UserID)
    #return @transcribers if record_info.Confirmed & ENTRY_SYSTEM || record_info.Confirmed & ENTRY_REFERENCE
  end

  def get_approved_scanslists
    self.best_guess_hash.scan_lists.approved
  end

  def get_unapproved_definitive_scanslists
    self.best_guess_hash.scan_lists.non_definite.unrejected.definitive unless get_approved_scanslists.present?
  end

  def get_unapproved_probable_scanslists
    self.best_guess_hash.scan_lists.non_definite.unrejected.probable unless get_unapproved_definitive_scanslists.present?
  end

  def get_rejected_probable_scanslists
    self.best_guess_hash.scan_lists.non_definite.rejected.probably_confirm unless get_unapproved_probable_scanslists.present?
  end

  def get_rejected_possible_scanslists
    self.best_guess_hash.scan_lists.non_definite.rejected.possibly_confirm unless get_rejected_probable_scanslists.present?
  end

  def get_rejected_likely_scanslists
    self.best_guess_hash.scan_lists.non_definite.rejected.can_be_confirm unless get_rejected_possible_scanslists.present?
  end

  def get_scanlists
    get_approved_scanslists + get_unapproved_definitive_scanslists + get_unapproved_probable_scanslists + get_rejected_probable_scanslists + get_rejected_possible_scanslists + get_rejected_likely_scanslists
  end

  def uniq_scanlists
    get_scanlists.uniq[0..5] if get_scanlists.present?
  end

  def record_accessions
    self.best_guess_links.pluck(:AccessionNumber)
  end

  def record_accession_pages
    #Accession.where(AccessionNumber: record_accessions).pluck(:Page)
    #self.best_guess_links.each {|link|
     # link.accession.Page
    #}
  end

  def find_accessions
    Accession.where(AccessionNumber: record_accessions)
  end

  def accession_info
    raw_pages = find_accessions.pluck(:Page)
    @pages = raw_pages + raw_pages.select{|m| m.length > 3}.map{|m| m.last(3)}
    @sources = find_accessions.pluck(:SourceID)
    @qne = event_quarter_number
  end

  def page_scans
    accession_info
    ImageFile
    .select(image_fileds)
    .joins(:image_pages, range:[:source])
    .where('ImagePage.PageNumber' => @pages, 'Source.QuarterEventNumber' => @qne )
  end

  def series_scans
    accession_info
    ImageFile
    .select(image_fileds)
    .joins(:image_pages, range:[:source])
    .where('Source.SeriesID' => @sources ) unless page_scans.present?
  end

  def filename_scans
    accession_info
    ImageFile
    .select(image_fileds)
    .joins(:image_pages, range:[:source])
    .where('ImageFile.Filename' => @sources ) unless page_scans.present?
  end

  def image_fileds
    'ImagePage.PageNumber, ImagePage.Implied, ImageFile.ImageID, ImageFile.MultipleFiles, ImageFile.Filename, ImageFile.StartLetters, ImageFile.EndLetters, Range.RangeID, Range.Range, Source.SourceID, Source.SeriesID'
  end

  def combined_scans
    scans = page_scans if page_scans.present?
    unless page_scans.present?
      if series_scans.present? && filename_scans.present?
        scans = series_scans + filename_scans
      elsif series_scans.present? && !filename_scans.present?
        scans = series_scans if series_scans.present?
      else 
        scans =  filename_scans
      end
    end
    scans
  end

  def get_non_implied_scans
    combined_scans.where('ImagePage.Implied' => 0) if combined_scans.present?
  end

  def scan_with_range
    get_non_implied_scans.reject{|s| s.Range = ""} if get_non_implied_scans.present?
  end

  def best_probable_scans
    surname_start_letter = self.Surname[0].upcase
    byebug
    get_non_implied_scans.select{|scan|
      if scan.StartLetters.present? && scan.EndLetters.present?
        raise ((scan.StartLetters.upcase...scan.EndLetters.upcase).include?(surname_start_letter)).inspect
        (scan.StartLetters.upcase...scan.EndLetters.upcase).include?(surname_start_letter)
      elsif scan.range.StartLetters.present? && scan.range.EndLetters.present?
        (scan.range.StartLetters.upcase...scan.range.EndLetters.upcase).include?(surname_start_letter)
      else
      end
    } if get_non_implied_scans.present?
  end

  def multiple_best_probable_scans
    unless uniq_scanlists.present?
      best_probable_scans.reject{|scan| scan.MultipleFiles = 0 }.uniq[0..6] if best_probable_scans.present?
    end
  end

  def get_non_multiple_scans
    raise best_probable_scans.inspect
    unless uniq_scanlists.present?
      best_probable_scans.select{|scan| scan.MultipleFiles = 0 }.uniq[0..6] if best_probable_scans.present?
    end
  end

  def final_acc_scans
    best_probable_scans unless get_scanlists.present?
  end

  def get_component_images
    ComponentFile.where(ImageID: multiple_best_probable_scans.pluck(:ImageID))
  end

  def multi_image_filenames
    get_component_images.pluck(:Filename)
  end

  def event_quarter_number
    #return (($year - 1837)*4 + $quarter)*3 + $event;
    qne = []
    find_accessions.each {|acc|
      qne << ((acc.Year - 1837) * 4 + acc.EntryQuarter) * 3 + acc.RecordTypeID
    }
    qne
  end

  def record_accession_sources
    Accession.where(AccessionNumber: record_accessions).pluck(:SorceID)
    #self.best_guess_links.each {|link|
     # link.accession.Page
    #}
  end
  def postems_list
    postem_info = []
    get_hash = self.best_guess_hash.Hash
    Postem.where(Hash: get_hash).all
  end
end