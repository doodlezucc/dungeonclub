import 'dart:async';
import 'dart:isolate';

class Worker<T, R> {
  final SendPort collectorSocket;
  final FutureOr<R> Function(T input) work;

  Worker({
    required this.collectorSocket,
    required this.work,
  });

  FutureOr<void> workWithCollectorPort(T payload) async {
    final result = await work(payload);

    collectorSocket.send(WorkerResult(payload: payload, result: result));
  }
}

class WorkerResult<T, R> {
  final T payload;
  final R result;

  WorkerResult({required this.payload, required this.result});
}

Future<void> parallelize<T, R>(
  FutureOr<R> Function(T input) work,
  Iterable<T> inputs, {
  required void Function(T params, R result) onComputed,
  int maxThreads = 10,
}) async {
  final completer = Completer();

  bool isLastBatch = false;
  int startedThreads = 0;
  final threadFinishedEvent = StreamController<void>.broadcast();

  final collector = ReceivePort();
  collector.listen((message) {
    final workerMessage = message as WorkerResult<T, R>;

    onComputed(workerMessage.payload, workerMessage.result);

    startedThreads--;

    if (isLastBatch && startedThreads == 0) {
      completer.complete();
    } else {
      threadFinishedEvent.add(null);
    }
  });

  for (var input in inputs) {
    final worker = Worker(
      collectorSocket: collector.sendPort,
      work: work,
    );

    Isolate.spawn(worker.workWithCollectorPort, input);

    startedThreads++;
    if (startedThreads >= maxThreads) {
      await threadFinishedEvent.stream.first;
    }
  }

  isLastBatch = true;

  await completer.future;
}
