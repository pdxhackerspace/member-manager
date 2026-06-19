module ParkingNoticePrinting
  extend ActiveSupport::Concern

  private

  def parking_notice_pdf_and_cups_options(parking_notice, printer)
    force_letter = params[:layout].to_s.in?(%w[letter full_page])
    if !force_letter && printer.thermal_receipt_printer?
      pdf = ParkingNoticeReceiptPdf.new(
        parking_notice,
        layout: :thermal,
        thermal_width_mm: printer.thermal_roll_width_mm
      )
      [pdf, CupsService::THERMAL_PDF_OPTIONS]
    else
      [ParkingNoticeReceiptPdf.new(parking_notice, layout: :full_page), {}]
    end
  end

  def print_parking_notice(parking_notice, printer)
    pdf, cups_options = parking_notice_pdf_and_cups_options(parking_notice, printer)

    CupsService.print_data(
      pdf.render,
      printer.cups_printer_name,
      cups_printer_server: printer.cups_printer_server,
      filename: "parking_notice_#{parking_notice.id}.pdf",
      options: cups_options
    )
  end

  def print_parking_notice_to_printer(parking_notice, printer)
    cookies[:last_printer_id] = { value: printer.id.to_s, expires: 1.year.from_now }
    print_parking_notice(parking_notice, printer)
  end
end
