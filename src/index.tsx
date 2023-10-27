import { NativeEventEmitter, NativeModules } from 'react-native';

export type Product = {
  attributes: {
    description: {
      standard: string;
    };
    icuLocale: string;
    isFamilyShareable: number;
    kind: string;
    name: string;
    offerName: string;
    offers: {
      currencyCode: string;
      discounts: any[];
      price: string;
      priceFormatted: string;
      recurringSubscriptionPeriod: string;
    }[];
    subscriptionFamilyId: string;
  };
  href: string;
  id: string;
  type: string;
};

type ProductContainer = {
  id: string;
  jsonRepresentation: string;
};

export type Transaction = {
  productId: string;
  environment: string;
  quantity: number;
  bundleId: string;
  appAccountToken: string;
  originalTransactionId: string;
  isUpgraded: boolean;
  expiresDate: number;
  deviceVerificationNonce: string;
  signedDate: number;
  subscriptionGroupIdentifier: string;
  purchaseDate: number;
  type: string;
  transactionId: string;
  webOrderLineItemId: string;
  deviceVerification: string;
  inAppOwnershipType: string;
  originalPurchaseDate: number;
};

type TransactionContainer = {
  id: number;
  jsonRepresentation: string;
};

export type Event =
  | { kind: 'transactions'; transaction: Transaction }
  | { kind: 'products'; products: Product[] }
  | { kind: 'error'; error: string };

class PurchaseKit {
  module = NativeModules.PurchaseKit;
  private bridge: NativeEventEmitter;

  public constructor() {
    this.bridge = new NativeEventEmitter(this.module);
    this.module.initialize();
  }

  public async purchase(item: {
    productID: string;
    uuid: string;
  }): Promise<Transaction> {
    const result = await this.module.purchase(item);
    const container = JSON.parse(result.transaction) as TransactionContainer;
    return JSON.parse(container.jsonRepresentation);
  }

  public async getProducts(productIDs: string[]): Promise<Product[]> {
    const result = await this.module.getProducts(productIDs);
    const products = JSON.parse(result.products) as ProductContainer[];
    return products.map((product) => JSON.parse(product.jsonRepresentation));
  }

  public readReceipt(): Promise<string> {
    return this.module.getReceipt();
  }

  public getRecentTransactions(): void {
    return this.module.getRecentTransactions();
  }

  public addListener(
    event: 'transactions' | 'products' | 'error',
    callback: (
      event:
        | { kind: 'transactions'; transaction: Transaction[] }
        | { kind: 'products'; products: Product[] }
        | { kind: 'error'; error: string }
    ) => void
  ) {
    this.bridge.addListener(event, (value) => {
      if (event === 'transactions') {
        const payload = JSON.parse(value.payload) as TransactionContainer[];
        callback({
          kind: 'transactions',
          transaction: payload.map((transaction) =>
            JSON.parse(transaction.jsonRepresentation)
          ),
        });
      } else if (event === 'products') {
        const payload = JSON.parse(value.payload) as ProductContainer[];
        callback({
          kind: 'products',
          products: payload.map((product) =>
            JSON.parse(product.jsonRepresentation)
          ),
        });
      } else if (event === 'error') {
        callback({ kind: 'error', error: value.payload });
      }
    });
  }

  public removeListener(event: 'transactions' | 'products' | 'error') {
    this.bridge.removeAllListeners(event);
  }
}

export default PurchaseKit;
