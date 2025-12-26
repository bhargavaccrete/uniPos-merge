import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'handlers/order_handler.dart';
import 'handlers/kds_handler.dart';

Router createRouter() {
  final router = Router();

  router.get('/health', (req) {
    return Response.ok('{"status":"ok"}',
        headers: {'Content-Type': 'application/json'});
  });

  router.post('/orders', createOrderHandler);
  router.get('/kds/orders', getKdsOrdersHandler);
  router.put('/kds/orders/<id>/status', updateKdsStatusHandler); // Legacy: updates whole order
  router.put('/kds/orders/<id>/kot/<kotNumber>/status', updateKotStatusHandler); // New: updates specific KOT


  return router;
}
