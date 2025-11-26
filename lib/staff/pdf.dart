import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PDFReportGenerator {
  static Future<void> generateAndDownloadReport({
    required int trafficIncidents,
    required int vehicleRegistrations,
    required int passAppeals,
    required int illegalParking,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      print('📝 Starting PDF generation...');

      PermissionStatus status = await _requestStoragePermission();

      if (!status.isGranted) {
        print('❌ Storage permission denied: $status');
        throw Exception('Storage permission denied.');
      }

      print('✅ Storage permission granted');

      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy');
      final fromDateStr = dateFormat.format(fromDate);
      final toDateStr = dateFormat.format(toDate);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'TAR UMT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'UNIVERSITY OF MANAGEMENT AND TECHNOLOGY',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'VEHICLE REPORT',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'From: $fromDateStr  To: $toDateStr',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.black,
                    width: 1,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        _buildTableCell('Type', isHeader: true),
                        _buildTableCell('Case', isHeader: true),
                        _buildTableCell('Trend', isHeader: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Traffic Incidents'),
                        _buildTableCell(trafficIncidents.toString()),
                        _buildTableCell('- 200'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Vehicle Registration'),
                        _buildTableCell(vehicleRegistrations.toString()),
                        _buildTableCell('+ 30'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Pass Appeal'),
                        _buildTableCell(passAppeals.toString()),
                        _buildTableCell('- 20'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Illegal Parking'),
                        _buildTableCell(illegalParking.toString()),
                        _buildTableCell('+ 10'),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),

                pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Reports Generated: ${trafficIncidents + illegalParking}',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total Registrations: $vehicleRegistrations',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Total Appeals: $passAppeals',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Generated on ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await _saveAndOpenPDF(pdf, fromDateStr, toDateStr);
    } catch (e) {
      print('❌ Error generating PDF: $e');
      rethrow;
    }
  }

  static Future<PermissionStatus> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      print('🤖 Android SDK Version: ${androidInfo.version.sdkInt}');

      if (androidInfo.version.sdkInt >= 30) {
        print('📱 Using MANAGE_EXTERNAL_STORAGE permission (Android 11+)');
        final status = await Permission.manageExternalStorage.request();
        print('📱 MANAGE_EXTERNAL_STORAGE status: $status');
        return status;
      } else if (androidInfo.version.sdkInt >= 29) {
        print('📱 Using WRITE_EXTERNAL_STORAGE permission (Android 10)');
        final status = await Permission.storage.request();
        print('📱 STORAGE status: $status');
        return status;
      } else {
        print('📱 Using WRITE_EXTERNAL_STORAGE permission (Android 9)');
        final status = await Permission.storage.request();
        print('📱 STORAGE status: $status');
        return status;
      }
    } else if (Platform.isIOS) {
      print('🍎 iOS detected - requesting photo library permissions');
      return await Permission.photos.request();
    }
    return PermissionStatus.granted;
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<void> _saveAndOpenPDF(
      pw.Document pdf,
      String fromDate,
      String toDate,
      ) async {
    try {
      print('💾 Saving PDF file...');

      Directory? downloadDir;

      if (Platform.isAndroid) {
        downloadDir = await getExternalStorageDirectory();

        if (downloadDir == null) {
          downloadDir = Directory('/storage/emulated/0/Download');
        }
      } else if (Platform.isIOS) {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null) {
        throw Exception('Could not find storage directory');
      }

      print('📂 Download directory: ${downloadDir.path}');

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Vehicle_Report_$timestamp.pdf';
      final filePath = '${downloadDir.path}/$fileName';

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('✅ PDF saved successfully to: $filePath');
      print('📊 File size: ${(await file.length() / 1024).toStringAsFixed(2)} KB');
    } catch (e) {
      print('❌ Error saving PDF: $e');
      rethrow;
    }
  }
}