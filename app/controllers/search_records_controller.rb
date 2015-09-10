class SearchRecordsController < ApplicationController
  before_filter :viewed
  skip_before_filter :require_login
  def show
    @page_number = params[:page_number].to_i
    @search_record = SearchRecord.find(params[:id])
    @entry = @search_record.freereg1_csv_entry
    @individual = @search_record.freecen_individual
    @dwelling = @individual.freecen_dwelling if @individual
    @cen_year = ' '
    @cen_piece = ' '
    if @dwelling && @dwelling.freecen1_vld_file
      @cen_year = @dwelling.freecen1_vld_file.full_year
      @cen_piece = @dwelling.freecen1_vld_file.piece
    end
    if params[:search_id].nil?
      redirect_to new_search_query_path
      return
    end
    begin
      @search_query = SearchQuery.find(params[:search_id])
      @previous_record = @search_query.previous_record(params[:id])
      @next_record = @search_query.next_record(params[:id])
    rescue Mongoid::Errors::DocumentNotFound
      log_possible_host_change
      redirect_to new_search_query_path
      return
    end
    @entry.display_fields if @entry
    @annotations = Annotation.find(@search_record.annotation_ids) if @search_record.annotation_ids
    session[:viewed] << params[:id] unless  session[:viewed].length >= 10
  end

  def show_print_version
    @page_number = params[:page_number].to_i
    @search_record = SearchRecord.find(params[:id])
    @entry = @search_record.freereg1_csv_entry
    if params[:search_id].nil?
      redirect_to new_search_query_path
      return
    end
    begin
      @search_query = SearchQuery.find(params[:search_id])
      @previous_record = @search_query.previous_record(params[:id])
      @next_record = @search_query.next_record(params[:id])
    rescue Mongoid::Errors::DocumentNotFound
      log_possible_host_change
      redirect_to new_search_query_path
      return
    end
    @annotations = Annotation.find(@search_record.annotation_ids) if @search_record.annotation_ids
    render "show", :layout => false
  end

  def viewed
    session[:viewed] ||= []
  end


end
