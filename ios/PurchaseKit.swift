import Foundation
import StoreKit
import React
import Combine

final class StoreKitObservedModel: ObservableObject {
    
    enum PurchaseError: Error {
        case pending, failed, cancelled
    }
    
    enum ProductError: Error {
        case notFound, unknown
    }
    
    private var storeKitTaskHandle: Task<Void, Error>?
    private var storeKitTaskHandleUpdates: Task<Void, Error>?
    @Published var purchasedProducts: Set<Transaction> = []
    @Published var availableProducts: [Product] = []
    
    var isSubscribed: Bool {
        !purchasedProducts.isEmpty
    }
    
    init() {
        storeKitTaskHandle = listenForStoreKitEntitlements()
        storeKitTaskHandleUpdates = listenForStoreKitUpdates()
    }
    
    @MainActor
    func purchase(productID: String, token: String) async throws -> Transaction {
        guard let token = UUID(uuidString: token) else {
            throw PurchaseError.failed
        }
        let setToken = Product
            .PurchaseOption
            .appAccountToken(token)
        let result = try await availableProducts.first(where: { product in
            product.id == productID
        })?.purchase(options: [setToken])
        switch result {
        case .pending:
            throw PurchaseError.pending
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                if !purchasedProducts.contains(transaction) {
                    purchasedProducts.insert(transaction)
                }
                return transaction
            case .unverified:
                throw PurchaseError.failed
            }
        case .userCancelled:
            throw PurchaseError.cancelled
        default:
            throw PurchaseError.failed
        }
    }
    
    @MainActor
    func loadProducts(products: [String]) async throws -> [Product] {
        do {
            let products = try await Product.products(
                for: Set(products)
            )
            if products.isEmpty {
                throw ProductError.notFound
            }

            products.forEach { product in
                if !availableProducts.contains(product) {
                    availableProducts.append(product)
                }
            }            

            return products
        } catch {
            print("Failed to fetch products.")
            throw ProductError.notFound
        }
    }
    
    private func listenForStoreKitEntitlements() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.currentEntitlements {
                await self.handleStoreKitUpdates(result: result)
            }
        }
    }
    
    private func listenForStoreKitUpdates() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                await self.handleStoreKitUpdates(result: result)
            }
        }
    }
    
    @MainActor
    private func handleStoreKitUpdates(result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            print("Transaction verified in listener")
            if !purchasedProducts.contains(transaction) {
                purchasedProducts.insert(transaction)
            }
            await transaction.finish()
        case .unverified:
            print("Transaction unverified")
        }
    }
    
    @MainActor
    func recentTransactions() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // TODO: review this
            if transaction.revocationDate == nil {
                print("Transaction", transaction)
                if !purchasedProducts.contains(transaction) {
                    purchasedProducts.insert(transaction)
                }
            } else {
                print("Removed transaction", transaction)
                purchasedProducts.remove(transaction)
            }
        }
    }
    
    func receiptString() -> String? {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                print(receiptData)
                let receiptString = receiptData.base64EncodedString(options: [])
                return receiptString
            }
            catch {
                print("Couldn't read receipt data with error: " + error.localizedDescription)
                return nil
            }
        }
        return nil
    }
}

@objc(PurchaseKit)
final class PurchaseKit: RCTEventEmitter {
    
    var cancellables = Set<AnyCancellable>()
    private lazy var store = StoreKitObservedModel()
    
    @objc
    public static var emitter: RCTEventEmitter?
    
    private static var isInitialized = false
    
    private static var queue: [Action] = []
    
    @objc
    override init() {
        super.init()
        Self.emitter = self
    }
    
    @objc(initialize)
    public func initialize() {
        store.$availableProducts.sink { products in
            do {
                guard !products.isEmpty else {
                    return
                }
                if let payload = String(data: try JSONEncoder().encode(products), encoding: .utf8) {
                    Self.dispatch(type: "products", payload: payload)
                }
            } catch {
                Self.dispatch(type: "error", payload: "Failed to encode products. \(error)")
            }
        }.store(in: &cancellables)
        
        store.$purchasedProducts.sink { transactions in
            guard !transactions.isEmpty else {
                return
            }
            do {
                if let payload = String(data: try JSONEncoder().encode(transactions), encoding: .utf8) {
                    Self.dispatch(type: "transactions", payload: payload)
                }
            } catch {
                Self.dispatch(type: "error", payload: "Failed to encode transactions. \(error)")
            }
        }.store(in: &cancellables)
    }
    
    @objc public override func supportedEvents() -> [String] {
        ["transactions", "products", "error"]
    }
    
    struct Action {
        let type: String
        let payload: String
    }
    
    @objc
    public static func dispatch(type: String, payload: String) {
        let actionObj = Action(type: type, payload: payload)
        if isInitialized {
            self.sendStoreAction(actionObj)
        } else {
            self.queue.append(actionObj)
        }
    }
    
    private static func sendStoreAction(_ action: Action) {
        if let emitter = self.emitter {
            emitter.sendEvent(withName: action.type, body: [
                "payload": action.payload
            ])
        }
    }
    
    @objc public override func startObserving() {
        Self.isInitialized = true
        for event in Self.queue {
            Self.sendStoreAction(event)
        }
        Self.queue = []
    }
    
    @objc
    public override func stopObserving() {
        Self.isInitialized = false
    }
}

struct InputConfig: Codable {
    let productID: String
    let uuid: String
}

extension PurchaseKit {
    @objc(purchase:withResolver:withRejecter:)
    public func purchase(input: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        print(input)
        Task {
            do {
                let decoded = try DictionaryDecoder()
                    .decode(InputConfig.self, from: input)
                let result = try await store.purchase(
                    productID: decoded.productID,
                    token: decoded.uuid
                )
                if let payload = String(data: try JSONEncoder().encode(result), encoding: .utf8) {
                    resolve([
                        "transaction" : payload
                    ])
                } else {
                    reject("error", "Failed to purchase product.", NSError(domain: "purchase", code: 0, userInfo: nil))
                }
            } catch {
                reject("error", "Failed to purchase product.", error)
            }
        }
    }
    
    @objc(getProducts:withResolver:withRejecter:)
    public func getProducts(productIDs: [String], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        print(productIDs)
        Task {
            do {
                let products = try await store.loadProducts(products: productIDs)
                if let payload = String(data: try JSONEncoder().encode(products), encoding: .utf8) {
                    resolve([
                        "products": payload
                    ])
                }
            } catch {
                reject("error", "Failed to load products.", error)
            }
        }
    }
    
    @objc(getReceipt:withRejecter:)
    public func getReceipt(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if let receipt = store.receiptString() {
            resolve([
                "receipt": receipt
            ])
        } else {
            reject("error", "Failed to load receipt.", NSError(domain: "receipt", code: 0, userInfo: nil))
        }
    }
    
    @objc(getRecentTransactions)
    public func getRecentTransactions() {
        Task.init {
            await store.recentTransactions()
        }
    }
}

extension Product: Encodable {
    enum CodingKeys: String, CodingKey {
        case id, jsonRepresentation
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container
            .encode(
                String(data: jsonRepresentation, encoding: .utf8),
                forKey: .jsonRepresentation
            )
    }
}

extension Transaction: Encodable {
    enum CodingKeys: String, CodingKey {
        case id, jsonRepresentation
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container
            .encode(
                String(data: jsonRepresentation, encoding: .utf8),
                forKey: .jsonRepresentation
            )
    }
}
