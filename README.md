<br/>
<div align="center">
  <a alt="npm" href="https://www.npmjs.com/package/react-native-purchase-kit">
      <img alt="npm downloads" src="https://img.shields.io/npm/dm/%40candlefinance%2Freact-native-purchase-kit.svg"/>
  </a>
  <a alt="discord users online" href="https://discord.gg/qnAgjxhg6n" 
  target="_blank"
  rel="noopener noreferrer">
    <img alt="discord users online" src="https://img.shields.io/discord/986610142768406548?label=Discord&logo=discord&logoColor=white&cacheSeconds=3600"/>
</div>

<br/>

<h1 align="center">
 StoreKit 2 for React Native
</h1>

<br/>

It's built on top of the latest StoreKit 2 and Android Billing Library 3.0.0+ (coming soon). At the moment, it only supports subscriptions and there is a single API for both platforms. Check out below.

## Installation

Requires `iOS 15+` and Android `minSdkVersion = 24`.

```sh
yarn add react-native-purchase-kit

```

## Basic Usage

Configure app to use [StoreKit 2](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode/) and [Android Billing](https://developer.android.com/google/play/billing/integrate) Library 3.0.0+.

```js
import PurchaseKit from 'react-native-purchase-kit';

const kit = new PurchaseKit();

// Get products
const products = await kit.getProducts(['monthly_subscription']);

// Buy a product
const transaction = await kit.purchase({
  productID: 'monthly_subscription',
  uuid: 'uuid',
});

// Get recent transactions
kit.getRecentTransactions();

// Get receipt
const receipt = await kit.readReceipt();

// Listen to events
kit.addListener('transactions', (event) => {
  if (event.kind === 'transactions') {
    console.log(event.transaction);
  }
});
```

## License

MIT
