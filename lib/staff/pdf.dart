import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      PermissionStatus status = await _requestStoragePermission();

      if (!status.isGranted) {
        throw Exception('Storage permission denied.');
      }

      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy');
      final fromDateStr = dateFormat.format(fromDate);
      final toDateStr = dateFormat.format(toDate);

      // Calculate trends (last month data)
      final lastMonthData = await _getLastMonthData();
      final trafficTrend = trafficIncidents - (lastMonthData['trafficIncidents'] ?? 0);
      final registrationTrend = vehicleRegistrations - (lastMonthData['vehicleRegistrations'] ?? 0);
      final appealTrend = passAppeals - (lastMonthData['passAppeals'] ?? 0);
      final parkingTrend = illegalParking - (lastMonthData['illegalParking'] ?? 0);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Header without logo
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'TAR UMT',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.Text(
                        'UNIVERSITY OF MANAGEMENT AND TECHNOLOGY',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
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
                        _buildTableCell('Count', isHeader: true),
                        _buildTableCell('Trends', isHeader: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Traffic Incidents'),
                        _buildTableCell(trafficIncidents.toString()),
                        _buildTrendCell(trafficTrend),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Vehicle Registration'),
                        _buildTableCell(vehicleRegistrations.toString()),
                        _buildTrendCell(registrationTrend),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Pass Appeal'),
                        _buildTableCell(passAppeals.toString()),
                        _buildTrendCell(appealTrend),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Illegal Parking'),
                        _buildTableCell(illegalParking.toString()),
                        _buildTrendCell(parkingTrend),
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

      await _saveAndOpenPDF(pdf);
    } catch (e) {
      print('Error in PDF generation: $e');
      rethrow;
    }
  }

  static Future<Map<String, int>> _getLastMonthData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1);

      final firstDayLastMonth = DateTime(lastMonth.year, lastMonth.month, 1);
      final lastDayLastMonth = DateTime(now.year, now.month, 0);

      // Get all reports and filter by date in code
      final allReports = await firestore
          .collection('report')
          .get()
          .timeout(const Duration(seconds: 5));

      final lastMonthReports = allReports.docs.where((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        final date = timestamp.toDate();
        return date.isAfter(firstDayLastMonth) && date.isBefore(lastDayLastMonth.add(Duration(days: 1)));
      }).toList();

      final trafficIncidents = lastMonthReports
          .where((doc) => doc.data()['reportType'] == 'Accident')
          .length;

      final illegalParking = lastMonthReports
          .where((doc) => doc.data()['reportType'] == 'Illegal Parking')
          .length;

      final registrationSnapshot = await firestore
          .collection('registration')
          .get()
          .timeout(const Duration(seconds: 5));

      final lastMonthRegistrations = registrationSnapshot.docs.where((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        final date = timestamp.toDate();
        return date.isAfter(firstDayLastMonth) && date.isBefore(lastDayLastMonth.add(Duration(days: 1)));
      }).length;

      final appealSnapshot = await firestore
          .collection('Appeal')
          .get()
          .timeout(const Duration(seconds: 5));

      final lastMonthAppeals = appealSnapshot.docs.where((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        final date = timestamp.toDate();
        return date.isAfter(firstDayLastMonth) && date.isBefore(lastDayLastMonth.add(Duration(days: 1)));
      }).length;

      return {
        'trafficIncidents': trafficIncidents,
        'vehicleRegistrations': lastMonthRegistrations,
        'passAppeals': lastMonthAppeals,
        'illegalParking': illegalParking,
      };
    } catch (e) {
      print('Error fetching last month data: $e');
      return {
        'trafficIncidents': 0,
        'vehicleRegistrations': 0,
        'passAppeals': 0,
        'illegalParking': 0,
      };
    }
  }

  static Future<PermissionStatus> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;

        if (androidInfo.version.sdkInt >= 30) {
          return await Permission.manageExternalStorage.request();
        } else {
          return await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        return await Permission.photos.request();
      }
      return PermissionStatus.granted;
    } catch (e) {
      print('Error requesting permission: $e');
      return PermissionStatus.denied;
    }
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

  static pw.Widget _buildTrendCell(int trend) {
    final trendText = trend > 0 ? '+$trend' : '$trend';
    final color = trend > 0 ? PdfColors.red : PdfColors.green;

    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        trendText,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static Future<void> _saveAndOpenPDF(pw.Document pdf) async {
    try {
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

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Vehicle_Report_$timestamp.pdf';
      final filePath = '${downloadDir.path}/$fileName';

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('PDF saved to: $filePath');
    } catch (e) {
      print('Error saving PDF: $e');
      rethrow;
    }
  }
}