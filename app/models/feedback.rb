class Feedback
  include Mongoid::Document
  include Mongoid::Timestamps
  field :title, type: String
  field :body, type: String
  field :feedback_time, type: DateTime
  field :user_id, type: String
  field :name, type: String
  field :email_address, type: String
  field :session_id, type: String
  field :problem_page_url, type: String
  field :previous_page_url, type: String
  field :feedback_type, type: String
  field :github_issue_url, type: String
  field :github_comment_url, type: String
  field :github_number, type: String
  field :session_data, type: Hash
  field :screenshot_location, type: String
  field :screenshot, type: String
  field :identifier, type: String
  field :contact_action_sent_to_userid, type: String, default: nil
  field :copies_of_contact_action_sent_to_userids, type: Array, default: Array.new
  field :archived, type: Boolean, default: false
  attr_accessor :action

  mount_uploader :screenshot, ScreenshotUploader

  validate :title_or_body_exist

  before_create :url_check, :add_identifier, :add_email, :add_screenshot_location

  module FeedbackType
    ISSUE='issue' #log a GitHub issue
    # To be added: contact form and other problems
  end

  class << self
    def id(id)
      where(:id => id)
    end

    def archived(value)
      where(:archived => value)
    end

    def github_enabled
      !Rails.application.config.github_issues_password.blank?
    end
  end


  def acknowledge_feedback
    UserMailer.acknowledge_feedback(self).deliver_now
  end

  def action_recipient_userid
    role = 'website_coordinator'
    person = UseridDetail.role(role).active(true).first
    person = UseridDetail.secondary(role).active(true).first if person.blank?
    person.present? ? action_person = person.userid : action_person = self.get_manager
    self.update_attribute(:contact_action_sent_to_userid,action_person)
    return action_person
  end

  def action_recipient_copies_userids(action_person)
    action_recipient_copies_userids = Array.new
    role = 'website_coordinator'
    UseridDetail.role(role).active(true).all.each do |person|
      action_recipient_copies_userids.push(person.userid) unless person.userid == action_person
    end
    UseridDetail.secondary(role).active(true).all.each do |person|
      action_recipient_copies_userids.push(person.userid) unless person.userid == action_person
    end
    action_recipient_copies_userids = action_recipient_copies_userids.uniq
    self.update_attribute(:copies_of_contact_action_sent_to_userids,action_recipient_copies_userids)
    return action_recipient_copies_userids
  end

  def add_contact_coordinator_to_copies_of_contact_action_sent_to_userids
    copies_of_contact_action_sent_to_userids = self.copies_of_contact_action_sent_to_userids
    action_person = UseridDetail.role("contacts_coordinator").active(true).first
    action_person = UseridDetail.secondary("contacts_coordinator").active(true).first if action_person.blank?
    if action_person.present? && !(action_person.userid == self.contact_action_sent_to_userid)
      if copies_of_contact_action_sent_to_userids.blank?
        copies_of_contact_action_sent_to_userids.push(action_person.userid)
      else
        copies_of_contact_action_sent_to_userids.push(action_person.userid) unless  copies_of_contact_action_sent_to_userids.include?(action_person.userid)
      end
    end
    self.update_attribute(:copies_of_contact_action_sent_to_userids, copies_of_contact_action_sent_to_userids)
    copies_of_contact_action_sent_to_userids
  end

  def add_identifier
    self.identifier = Time.now.to_i - Time.gm(2015).to_i
  end

  def add_email
    reporter = UseridDetail.userid(self.user_id).first
    self.email_address = reporter.email_address unless reporter.nil?
    self.name = reporter.person_forename unless reporter.nil?
  end

  def add_link_to_attachment
    return if self.screenshot_location.blank?
    website = Rails.application.config.website
    website  = website.sub("www","www13") if website == "http://www.freereg.org.uk"
    go_to = "#{website}/#{self.screenshot_location}"
    body = self.body + "\n" + go_to
    self.update_attribute(:body,body)
  end

  def add_screenshot_location
    self.screenshot_location = "uploads/feedback/screenshot/#{self.screenshot.model._id.to_s}/#{self.screenshot.filename}" if self.screenshot.filename.present?
  end

  def add_sender_to_copies_of_contact_action_sent_to_userids(sender_userid)
    p "adding sender"
     p copies_of_contact_action_sent_to_userids
    copies_of_contact_action_sent_to_userids = self.copies_of_contact_action_sent_to_userids
    copies_of_contact_action_sent_to_userids.push(sender_userid) unless  copies_of_contact_action_sent_to_userids.include?(sender_userid)
    self.update_attribute(:copies_of_contact_action_sent_to_userids, copies_of_contact_action_sent_to_userids)
     p copies_of_contact_action_sent_to_userids
    copies_of_contact_action_sent_to_userids
  end

  def communicate_feedback_reply(message,sender_userid)
    copies = self.copies_of_contact_action_sent_to_userids
    p "Hello"
    p sender_userid
    recipients = Array.new
    recipients.push(self.email_address)
    UserMailer.coordinator_feedback_reply(self,copies,message,sender_userid).deliver_now
    p "sent"
    
    copies = self.add_sender_to_copies_of_contact_action_sent_to_userids(sender_userid)
    p "copies"
    p copies
    reply_sent_messages(message,sender_userid,recipients,copies)
  end

  def communicate_initial_contact
    self.acknowledge_feedback
    self.feedback_action_communication
  end

  def feedback_action_communication
    send_to_userid = self.action_recipient_userid
    #copies_of_contact_action_sent_to_userids = self.add_contact_coordinator_to_copies_of_contact_action_sent_to_userids
    UserMailer.feedback_action_request(self,send_to_userid,copies_of_contact_action_sent_to_userids).deliver_now
    #copies = self.add_sender_to_copies_of_contact_action_sent_to_userids(send_to_userid)
  end

  def get_manager
    action_person = UseridDetail.role("contacts_coordinator").active(true).first
    action_person = UseridDetail.secondary("contacts_coordinator").active(true).first if action_person.blank?
    action_person = UseridDetail.userid("REGManager").active(true).first if action_person.blank?
    action_person = UseridDetail.role("system_administrator").active(true).first if action_person.blank?
    return action_person.userid
  end

  def github_issue
    if Feedback.github_enabled
      self.add_link_to_attachment
      Octokit.configure do |c|
        c.login = Rails.application.config.github_issues_login
        c.password = Rails.application.config.github_issues_password
      end
      self.screenshot = nil
      response = Octokit.create_issue(Rails.application.config.github_issues_repo, issue_title, issue_body, :labels => [])
      logger.info("FREEREG:GITHUB response: #{response}")
      logger.info(response.inspect)
      self.update_attributes(:github_issue_url => response[:html_url],:github_comment_url => response[:comments_url], :github_number => response[:number])
    else
      logger.error("FREEREG:Tried to create an issue, but Github integration is not enabled!")
    end
  end

  def has_replies?(feedback_id)
    Message.where(source_feedback_id: feedback_id).exists?
  end

  def issue_body
    issue_body = ApplicationController.new.render_to_string(:partial => 'feedbacks/github_issue_body.txt', :locals => {:feedback => self})
    issue_body
  end

  def issue_title
    "#{identifier} #{title} (#{name})"
  end

  def is_archived?
    return self.archived
  end

  def member_can_reply?(user)
    @user = user
    permitted_person_role || permitted_secondary_role
  end

  def title_or_body_exist
    errors.add(:title, "Either the Summary or Body must have content") if self.title.blank? && self.body.blank?
  end

  def url_check
    self.problem_page_url = "unknown" if self.problem_page_url.nil?
    self.previous_page_url = "unknown" if self.previous_page_url.nil?
  end


  private

  def permitted_person_role
    ReplyUseridRole::FEEDBACK_REPLY_ROLE.include?(@user.person_role)
  end

  def permitted_secondary_role
    (@user.secondary_role & ReplyUseridRole::FEEDBACK_REPLY_ROLE).any?
  end

  def reply_sent_messages(message, sender_userid,contact_recipients,other_recipients)
    p contact_recipients
    p other_recipients
    @message = message
    @sent_message = SentMessage.new(message_id: @message.id, sender: sender_userid, recipients: contact_recipients, other_recipients: other_recipients, sent_time: Time.now)
    @message.sent_messages <<  [ @sent_message ]
    @sent_message.save
  end

  def update_reply_for_feedback(person,message)
    @feedback_userid = person.userid_feedback_replies
    if @feedback_userid.has_key?(self.id.to_s)
      @feedback_userid[self.id.to_s] << message.id.to_s unless @feedback_userid[self.id.to_s].include?(message.id.to_s)
      person.update_attribute(:userid_feedback_replies, @feedback_userid)
    end
  end

end
