import 'package:googleapis/docs/v1.dart' as docs;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/bill.dart';

class _CellInsert {
  final int index;
  final String text;
  _CellInsert(this.index, this.text);
}


/// Merge [rowSpan] rows x [columnSpan] columns, starting at ([startRow], [column]).
class RowMerge {
  final int startRow;
  final int column;
  final int rowSpan;
  final int columnSpan;
  RowMerge(this.startRow, this.column, this.rowSpan, {this.columnSpan = 1});
}

class DocsService {
  final GoogleSignIn googleSignIn;
  DocsService(this.googleSignIn);

  Future<docs.DocsApi> _getDocsApi() async {
    final client = await googleSignIn.authenticatedClient();
    if (client == null) throw Exception('Not signed in.');
    return docs.DocsApi(client);
  }

  // The document body always ends with a final newline you can't delete;
  // new content goes right before it.
  Future<int> _getEndIndex(docs.DocsApi api, String documentId) async {
    final doc = await api.documents.get(documentId);
    final content = doc.body?.content;
    if (content == null || content.isEmpty) return 1;
    final lastEndIndex = content.last.endIndex ?? 1;
    return lastEndIndex - 1;
  }

  Future<void> _batch(
      docs.DocsApi api, String documentId, List<docs.Request> requests) async {
    if (requests.isEmpty) return;
    await api.documents.batchUpdate(
      docs.BatchUpdateDocumentRequest(requests: requests),
      documentId,
    );
  }

  Future<String> createDocument(String title) async {
    final api = await _getDocsApi();
    final doc = await api.documents.create(docs.Document(title: title));
    return doc.documentId!;
  }

  Future<void> _appendStyledLine(
    String documentId,
    String text, {
    required double fontSize,
  }) async {
    final api = await _getDocsApi();
    final index = await _getEndIndex(api, documentId);
    await _batch(api, documentId, [
      docs.Request(
        insertText: docs.InsertTextRequest(
          text: '$text\n',
          location: docs.Location(index: index),
        ),
      ),
      docs.Request(
        updateTextStyle: docs.UpdateTextStyleRequest(
          range: docs.Range(startIndex: index, endIndex: index + text.length),
          textStyle: docs.TextStyle(
            bold: true,
            fontSize: docs.Dimension(magnitude: fontSize, unit: 'PT'),
          ),
          fields: 'bold,fontSize',
        ),
      ),
    ]);
  }

  Future<void> appendHeading(String documentId, String text) =>
      _appendStyledLine(documentId, text, fontSize: 16);

  Future<void> appendSectionTitle(String documentId, String text) =>
      _appendStyledLine(documentId, text, fontSize: 13);

  /// Inserts a table at the end of the doc. [rows] includes the header row
  /// as rows[0]; every inner list must be the same length.
      Future<void> appendTable(
    String documentId,
    List<List<String>> rows, {
    List<RowMerge> merges = const [],
    List<int> boldRows = const [],
    List<List<int>> boldCells = const [],
  }) async {
    final api = await _getDocsApi();
    final insertIndex = await _getEndIndex(api, documentId);

    await _batch(api, documentId, [
      docs.Request(
        insertTable: docs.InsertTableRequest(
          rows: rows.length,
          columns: rows[0].length,
          location: docs.Location(index: insertIndex),
        ),
      ),
    ]);

    // Fill text (last cell first, so indices don't shift).
    var doc = await api.documents.get(documentId);
    var table = _findTableFrom(doc, insertIndex);
    if (table?.table == null) return;

    final cellInserts = <_CellInsert>[];
    final tableRows = table!.table!.tableRows ?? [];
    for (int r = 0; r < tableRows.length && r < rows.length; r++) {
      final cells = tableRows[r].tableCells ?? [];
      for (int c = 0; c < cells.length && c < rows[r].length; c++) {
        final text = rows[r][c];
        if (text.isEmpty) continue;
        final startIndex = cells[c].content?.first.startIndex;
        if (startIndex != null) cellInserts.add(_CellInsert(startIndex, text));
      }
    }
    cellInserts.sort((a, b) => b.index.compareTo(a.index));
    await _batch(
      api,
      documentId,
      cellInserts
          .map((c) => docs.Request(
                insertText: docs.InsertTextRequest(
                  text: c.text,
                  location: docs.Location(index: c.index),
                ),
              ))
          .toList(),
    );

    // Bold: re-fetch so we use the indices AFTER the text went in.
    if (boldRows.isNotEmpty || boldCells.isNotEmpty) {
      doc = await api.documents.get(documentId);
      table = _findTableFrom(doc, insertIndex);
      final liveRows = table?.table?.tableRows ?? [];
      final boldRequests = <docs.Request>[];

      void boldCell(int r, int c) {
        if (r >= liveRows.length) return;
        final cells = liveRows[r].tableCells ?? [];
        if (c >= cells.length) return;
        final content = cells[c].content;
        if (content == null || content.isEmpty) return;
        final start = content.first.startIndex;
        final end = (content.last.endIndex ?? 0) - 1; // exclude trailing newline
        if (start == null || end <= start) return; // empty cell
        boldRequests.add(docs.Request(
          updateTextStyle: docs.UpdateTextStyleRequest(
            range: docs.Range(startIndex: start, endIndex: end),
            textStyle: docs.TextStyle(bold: true),
            fields: 'bold',
          ),
        ));
      }

      for (final r in boldRows) {
        for (int c = 0; c < rows[0].length; c++) {
          boldCell(r, c);
        }
      }
      for (final rc in boldCells) {
        boldCell(rc[0], rc[1]);
      }
      await _batch(api, documentId, boldRequests);
    }

    // Merge LAST. Table start index is unaffected by text edits inside cells.
    if (merges.isNotEmpty) {
      final tableStart = table!.startIndex!;
      final mergeRequests = <docs.Request>[];
      for (final m in merges) {
        final range = docs.TableRange(
          tableCellLocation: docs.TableCellLocation(
            tableStartLocation: docs.Location(index: tableStart),
            rowIndex: m.startRow,
            columnIndex: m.column,
          ),
          rowSpan: m.rowSpan,
          columnSpan: m.columnSpan,
        );
        mergeRequests.add(docs.Request(
          mergeTableCells: docs.MergeTableCellsRequest(tableRange: range),
        ));
        mergeRequests.add(docs.Request(
          updateTableCellStyle: docs.UpdateTableCellStyleRequest(
            tableRange: range,
            tableCellStyle: docs.TableCellStyle(contentAlignment: 'MIDDLE'),
            fields: 'contentAlignment',
          ),
        ));
      }
      await _batch(api, documentId, mergeRequests);
    }
  }

  docs.StructuralElement? _findTableFrom(docs.Document doc, int nearIndex) {
    final content = doc.body?.content ?? [];
    for (final el in content) {
      if (el.table != null && (el.startIndex ?? 0) >= nearIndex) return el;
    }
    for (final el in content.reversed) {
      if (el.table != null) return el;
    }
    return null;
  }

  Future<void> appendPageBreak(String documentId) async {
    final api = await _getDocsApi();
    final index = await _getEndIndex(api, documentId);
    await _batch(api, documentId, [
      docs.Request(
        insertPageBreak:
            docs.InsertPageBreakRequest(location: docs.Location(index: index)),
      ),
    ]);
  }

  Future<void> appendImage(String documentId, String imageUrl) async {
    final api = await _getDocsApi();
    final index = await _getEndIndex(api, documentId);
    await _batch(api, documentId, [
      docs.Request(
        insertInlineImage: docs.InsertInlineImageRequest(
          uri: imageUrl,
          location: docs.Location(index: index),
        ),
      ),
    ]);
  }

  String documentUrl(String documentId) =>
      'https://docs.google.com/document/d/$documentId/edit';

  /// Builds the full expense report from scratch and returns its edit URL.
  Future<String> generateReport({
    required String documentTitle,
    required Map<String, List<Bill>> groupedBills,
    required String Function(String driveFileId) imageUrlBuilder,
  }) async {
    final documentId = await createDocument(documentTitle);
    await appendHeading(documentId, '---- EXPENSE REPORT');

    final categoryTotals = <String, double>{};

    for (final category in groupedBills.keys) {
      final bills = groupedBills[category]!;
      final total = bills.fold<double>(0, (sum, b) => sum + b.amount);
      categoryTotals[category] = total;

      await appendSectionTitle(documentId, category);

                  final rows = <List<String>>[
        ['S.No.', 'Item', 'Price', 'Quantity', 'Amount', 'Bill no.'],
      ];
      final merges = <RowMerge>[];
      int sNo = 1;

      for (final bill in bills) {
        final startRow = rows.length;
        for (int j = 0; j < bill.items.length; j++) {
          final it = bill.items[j];
          rows.add([
            j == 0 ? '$sNo' : '', // S.No. is now per BILL, top cell only
            it.item,
            it.price.toStringAsFixed(2),
            it.quantity.toStringAsFixed(it.quantity % 1 == 0 ? 0 : 2),
            it.amount.toStringAsFixed(2),
            j == 0 ? '${bill.billNo}' : '',
          ]);
        }
        sNo++;
        if (bill.items.length > 1) {
          merges.add(RowMerge(startRow, 0, bill.items.length)); // S.No.
          merges.add(RowMerge(startRow, 5, bill.items.length)); // Bill no.
        }
      }

      // Total row: "Total" across columns 0-3, amount across columns 4-5.
      final totalRow = rows.length;
      rows.add(['Total', '', '', '', total.toStringAsFixed(2), '']);
      merges.add(RowMerge(totalRow, 0, 1, columnSpan: 4));
      merges.add(RowMerge(totalRow, 4, 1, columnSpan: 2));

      await appendTable(
        documentId,
        rows,
        merges: merges,
        boldRows: [0], // header row
        boldCells: [
          [totalRow, 0],
          [totalRow, 4],
        ],
      );
    }

    await appendSectionTitle(documentId, 'TOTAL');
    final grandTotal = categoryTotals.values.fold<double>(0, (a, b) => a + b);
    final entries = categoryTotals.entries.toList();
        final totalRows = <List<String>>[
      ['S.no.', 'Details', 'Amount'],
      for (int i = 0; i < entries.length; i++)
        ['${i + 1}', entries[i].key, entries[i].value.toStringAsFixed(2)],
      ['Grand Total', '', grandTotal.toStringAsFixed(2)],
    ];
    final lastRow = totalRows.length - 1;
    await appendTable(
      documentId,
      totalRows,
      merges: [RowMerge(lastRow, 0, 1, columnSpan: 2)],
      boldRows: [0],
      boldCells: [
        [lastRow, 0],
        [lastRow, 2],
      ],
    );

    final allBills = groupedBills.values.expand((b) => b).toList()
      ..sort((a, b) => a.billNo.compareTo(b.billNo));

    for (final bill in allBills) {
      if (bill.driveFileId == null) continue;
      await appendPageBreak(documentId);
      await appendHeading(documentId, 'Bill no. ${bill.billNo}');
      await appendImage(documentId, imageUrlBuilder(bill.driveFileId!));
    }

    return documentUrl(documentId);
  }
}