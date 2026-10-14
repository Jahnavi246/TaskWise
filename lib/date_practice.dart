
import 'package:intl/intl.dart';

void main() {
  final now = DateTime.now();

  print(DateFormat('d MMM yyyy').format(now));
  print(DateFormat('EEEE').format(now));
  print(DateFormat('h:mm a').format(now));
}
