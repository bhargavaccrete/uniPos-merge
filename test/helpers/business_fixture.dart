import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// Registers a business with tax registration OFF.
///
/// The POS prices every Captain order itself (Batch 3.2, P1/P2), which reads
/// the business's tax flag ([BusinessDetailsRepository.isTaxEnabled]). Tests
/// that send Captain orders but do not exercise tax call this in setUp.
void registerNoTaxBusinessForTest() {
  if (!locator.isRegistered<BusinessDetailsRepository>()) {
    locator.registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness());
  }
}
