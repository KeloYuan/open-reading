enum ReaderSelectionAction {
  highlight,
  note,
  askAi,
}

class ReaderSelectionPayload {
  final ReaderSelectionAction action;
  final String text;
  final int localStart;
  final int localEnd;
  final int globalStart;
  final int globalEnd;

  const ReaderSelectionPayload({
    required this.action,
    required this.text,
    required this.localStart,
    required this.localEnd,
    required this.globalStart,
    required this.globalEnd,
  });
}
