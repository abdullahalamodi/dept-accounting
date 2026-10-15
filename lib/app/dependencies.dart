import '../core/data/app_store.dart';
import '../core/data/local_database.dart';
import '../features/accounting/data/posting_engine.dart';
import '../features/backup/data/backup_service.dart';
import '../features/returns/data/returns_repository.dart';
import '../features/inventory/data/inventory_repository.dart';
import '../features/receiving/data/receiving_repository.dart';
import '../features/invoices/data/correction_repository.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/catalog_references_repository.dart';
import '../features/finance/data/finance_repository.dart';
import '../features/finance/data/credit_repository.dart';
import '../features/finance/data/reconciliation_repository.dart';
import '../features/invoices/data/invoice_repository.dart';
import '../features/parties/data/party_repository.dart';
import '../features/reports/data/reports_repository.dart';
import '../features/reports/data/export_service.dart';
import '../features/overview/data/overview_repository.dart';
import '../features/startup/data/startup_guide_repository.dart';

class AppDependencies {
  AppDependencies(LocalDatabase database) {
    store = AppStore(database);
    engine = PostingEngine(store);
    catalogReferences = CatalogReferencesRepository(store);
    catalog = CatalogRepository(store, engine, catalogReferences);
    parties = PartyRepository(store, engine);
    invoices = InvoiceRepository(store, engine, catalog, parties);
    finance = FinanceRepository(store, engine, invoices, parties);
    credits = CreditRepository(store, engine, invoices);
    reconciliation = ReconciliationRepository(store, engine);
    reports = ReportsRepository(store, engine);
    overview = OverviewRepository(store, invoices);
    startupGuide = StartupGuideRepository(store);
    backups = BackupService(store);
    returns = ReturnsRepository(store, engine, invoices, catalog);
    inventory = InventoryRepository(store, engine, catalog);
    receiving = ReceivingRepository(store, engine, catalog, parties, invoices);
    corrections = CorrectionRepository(store, engine, invoices);
  }
  late final AppStore store;
  late final PostingEngine engine;
  late final CatalogReferencesRepository catalogReferences;
  late final CatalogRepository catalog;
  late final PartyRepository parties;
  late final InvoiceRepository invoices;
  late final FinanceRepository finance;
  late final CreditRepository credits;
  late final ReconciliationRepository reconciliation;
  late final ReportsRepository reports;
  late final OverviewRepository overview;
  late final StartupGuideRepository startupGuide;
  final exports = ExportService();
  late final BackupService backups;
  late final ReturnsRepository returns;
  late final InventoryRepository inventory;
  late final ReceivingRepository receiving;
  late final CorrectionRepository corrections;
}
