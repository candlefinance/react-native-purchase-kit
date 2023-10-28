package com.purchasekit

import android.app.Activity
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetailsResult
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.queryProductDetails
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

class PurchaseKitModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val scope = CoroutineScope(Job() + Dispatchers.IO)
  private var job: Job? = null

  private val purchasesUpdatedListener =
    PurchasesUpdatedListener { billingResult, purchases ->
      if (!purchases.isNullOrEmpty()) {
        dispatch(transactions, mapOf(transactions to Gson().toJson(purchases)))
      } else {
        dispatch(transactions, mapOf(transactions to Gson().toJson(billingResult)))
      }
    }

  private var billingClient = BillingClient.newBuilder(this.reactApplicationContext)
    .setListener(purchasesUpdatedListener)
    .enablePendingPurchases()
    .build()

  @ReactMethod
  override fun initialize() {
    billingClient.startConnection(object : BillingClientStateListener {
      override fun onBillingSetupFinished(billingResult: BillingResult) {
        // To be implemented in a later section.
        println("onBillingSetupFinished")
      }

      override fun onBillingServiceDisconnected() {
        // To be implemented in a later section.
        println("onBillingServiceDisconnected")
      }
    })
  }

  @ReactMethod
  fun getProducts(productIDs: ReadableArray, promise: Promise) {
    val productIDs: Array<String> = Array(productIDs.size()) { i ->
      productIDs.getString(i)!!
    }
    for (productID in productIDs) {
      println("productID $productID")
    }
    runBlocking {
      job = scope.launch {
        val productDetailsResult = productDetailsResult(productIDs)

        productDetailsResult.productDetailsList?.forEach { productDetails ->
          println("productDetails $productDetails")
        }

        val toMap = productDetailsResult.productDetailsList?.map { productDetails ->
          mapOf(
            "id" to productDetails.productId,
            "jsonRepresentation" to Gson().toJson(productDetails)
          )
        }
        promise.resolve(Gson().toJson(toMap))
      }
    }
  }

  @ReactMethod
  fun purchase(product: ReadableMap, promise: Promise) {
    // To be implemented in a later section.
    println("purchaseProduct $product")
    runBlocking {
      job = scope.launch {
        val productID = product.getString("productID")
        val uuid = product.getString("uuid")

        val activity: Activity? = currentActivity

        val products = productID?.let { productDetailsResult(arrayOf(it)) }

        if (products?.productDetailsList != null && products.productDetailsList!!.isNotEmpty()) {
          val productDetails = products.productDetailsList?.get(0)

          val productDetailsParamsList = listOf(
            productDetails?.let {
              BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(it)
                .build()
            }
          )

          val billingFlowParams = uuid?.let {
            BillingFlowParams.newBuilder()
              .setProductDetailsParamsList(productDetailsParamsList)
              .setObfuscatedAccountId(it)
              .setObfuscatedProfileId(it)
              .build()
          }

          if (billingFlowParams != null) {
            if (activity != null) {
              val billingResult = billingClient.launchBillingFlow(activity, billingFlowParams)
              promise.resolve(mapOf(
                "id" to productID,
                "jsonRepresentation" to Gson().toJson(billingResult)
              ))
            } else {
              promise.reject("error", "Activity is null")
            }
          } else {
            promise.reject("error", "BillingFlowParams is null")
          }
        } else {
          promise.reject("error", "Products is empty")
        }
      }
    }
  }

  private suspend fun productDetailsResult(productIDs: Array<String>): ProductDetailsResult {
    val productList = ArrayList<QueryProductDetailsParams.Product>()
    for (productId in productIDs) {
      productList.add(
        QueryProductDetailsParams.Product.newBuilder()
          .setProductId(productId)
          .setProductType(BillingClient.ProductType.SUBS)
          .build()
      )
    }
    val params = QueryProductDetailsParams.newBuilder()
    params.setProductList(productList)

    val productDetailsResult = withContext(Dispatchers.IO) {
      billingClient.queryProductDetails(params.build())
    }
    return productDetailsResult
  }

  override fun getConstants() = mapOf(
    "products" to products,
    "transactions" to transactions,
    "error" to error
  )

  private fun dispatch(action: String, payload: Map<String, Any?>) {
    val map = mapOf(
      "payload" to Gson().toJson(payload)
    )
    val event: WritableMap = Arguments.makeNativeMap(map)
    reactApplicationContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(action, event)
  }

  @ReactMethod
  fun getRecentTransactions(promise: Promise) {
    // To be implemented in a later section.
    println("getRecentTransactions")
  }

  override fun getName(): String {
    return NAME
  }

  companion object {
    const val NAME = "PurchaseKit"
    const val products = "products"
    const val transactions = "transactions"
    const val error = "error"
  }
}
