import { NativeEventEmitter, NativeModules } from 'react-native';

class PurchaseKit {
  module = NativeModules.PurchaseKit;
  private bridge: NativeEventEmitter;

  public constructor() {
    this.bridge = new NativeEventEmitter(this.module);
    this.module.initialize();
  }

  public purchase(item: { productID: string; token: string }): Promise<any> {
    return this.module.purchase(item);
  }

  public getProducts(productIDs: string[]): Promise<any> {
    return this.module.getProducts(productIDs);
  }

  public readReceipt(): Promise<string> {
    return this.module.getReceipt();
  }

  public getRecentTransactions(): void {
    return this.module.getRecentTransactions();
  }

  public addListener(
    event: 'transactions' | 'products' | 'error',
    callback: (event: any) => void
  ) {
    this.bridge.addListener(event, (value) => {
      const payload = JSON.parse(value.payload);
      callback(payload);
    });
  }

  public removeListener(event: 'transactions' | 'products' | 'error') {
    this.bridge.removeAllListeners(event);
  }
}

export default PurchaseKit;
