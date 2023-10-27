import * as React from 'react';

import { Button, StyleSheet, View } from 'react-native';
import PurchaseKit from 'react-native-purchase-kit';

export default function App() {
  const kit = new PurchaseKit();

  React.useEffect(() => {
    kit.addListener('transactions', (event) => {
      if (event.kind === 'transactions') {
        console.log(event.transaction);
      }
    });
  }, []);

  const handleButtonPress = async (buttonNumber: number) => {
    console.log(`Button ${buttonNumber} pressed`);
    switch (buttonNumber) {
      case 0:
        const products = await kit.getProducts(['com.example.product']);
        console.log(products);
        break;
      case 1:
        const result = await kit.purchase({
          productID: 'com.example.product',
          uuid: 'token',
        });
        console.log(result);
        break;
      case 2:
        kit.getRecentTransactions();
        break;
      case 3:
        const receipt = await kit.readReceipt();
        console.log(receipt);
        break;
      default:
        break;
    }
  };

  return (
    <View style={styles.container}>
      <Button title="load products" onPress={() => handleButtonPress(0)} />
      <Button title="purchase" onPress={() => handleButtonPress(1)} />
      <Button title="get transactions" onPress={() => handleButtonPress(2)} />
      <Button title="read receipt" onPress={() => handleButtonPress(3)} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
