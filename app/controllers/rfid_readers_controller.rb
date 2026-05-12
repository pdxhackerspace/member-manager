# SPDX-FileCopyrightText: 2025 John Romkey
#
# SPDX-License-Identifier: CC0-1.0

class RfidReadersController < AdminController
  before_action :set_rfid_reader, only: %i[show edit update destroy regenerate_key]

  def index
    @rfid_readers = RfidReader.order(:name)
    @default_setting = DefaultSetting.instance
  end

  def show; end

  def new
    @rfid_reader = RfidReader.new
  end

  def edit; end

  def create
    @rfid_reader = RfidReader.new(rfid_reader_params)

    if @rfid_reader.save
      redirect_to rfid_readers_path, notice: 'RFID reader created successfully.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @rfid_reader.update(rfid_reader_params)
      redirect_to rfid_readers_path, notice: 'RFID reader updated successfully.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @rfid_reader.destroy
    redirect_to rfid_readers_path, notice: 'RFID reader deleted successfully.'
  end

  def update_facility_code
    @default_setting = DefaultSetting.instance

    if @default_setting.update(rfid_facility_code_params)
      redirect_to rfid_readers_path, notice: 'RFID facility code updated successfully.'
    else
      @rfid_readers = RfidReader.order(:name)
      flash.now[:alert] = 'Unable to update RFID facility code.'
      render :index, status: :unprocessable_content
    end
  end

  def regenerate_key
    @rfid_reader.generate_key!

    respond_to do |format|
      format.html { redirect_to edit_rfid_reader_path(@rfid_reader), notice: 'Key regenerated successfully.' }
      format.json { render json: { key: @rfid_reader.key } }
    end
  end

  private

  def set_rfid_reader
    @rfid_reader = RfidReader.find(params[:id])
  end

  def rfid_reader_params
    params.expect(rfid_reader: %i[name note])
  end

  def rfid_facility_code_params
    params.expect(default_setting: %i[rfid_facility_code])
  end
end
