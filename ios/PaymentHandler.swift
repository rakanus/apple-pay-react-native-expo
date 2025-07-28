import ExpoModulesCore
import PassKit

struct PaymentRequestItemData: Record {
    @Field
    var label: String
    
    @Field
    var amount: String
}

struct PaymentRequestData: Record {
    @Field
    var merchantIdentifier: String
    
    @Field
    var countryCode: String
    
    @Field
    var currencyCode: String
    
    @Field
    var merchantCapabilities: [String] = ["supports3DS"]
    
    @Field
    var supportedNetworks: [String]
    
    @Field
    var paymentSummaryItems: [PaymentRequestItemData]
}

typealias PaymentCompletionHandler = (PKPaymentAuthorizationResult) -> Void

class PaymentHandler: NSObject  {
    var paymentController: PKPaymentAuthorizationController?
    var promise: Promise!
    var handleCompletion: PaymentCompletionHandler?
    
    public func show(data: PaymentRequestData, promise: Promise) {
        self.promise = promise;
        
        let paymentRequest = PKPaymentRequest()
        paymentRequest.paymentSummaryItems = data.paymentSummaryItems.map {
            PKPaymentSummaryItem(label: $0.label, amount: NSDecimalNumber(string: $0.amount), type: .final)
        }
        
        paymentRequest.merchantIdentifier = data.merchantIdentifier
        paymentRequest.merchantCapabilities = getMerchantCapabilitiesFromData(jsMerchantCapabilities: data.merchantCapabilities)
        paymentRequest.countryCode = data.countryCode
        paymentRequest.currencyCode = data.currencyCode
        paymentRequest.supportedNetworks = getSupportedNetworksFromData(jsSupportedNetworks: data.supportedNetworks)
        
        //        paymentRequest.shippingType = .delivery
        //        paymentRequest.shippingMethods = shippingMethodCalculator()
        //        paymentRequest.requiredShippingContactFields = [.name, .postalAddress]
        
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController!.delegate = self
        paymentController!.present(completion: { (presented: Bool) in
            if presented {
            } else {
                self.promise.reject("no_show", "Failed to present")
                self.promise = nil
            }
        })
    }
    
    public func complete(status: PKPaymentAuthorizationStatus) {
        handleCompletion?(PKPaymentAuthorizationResult(status: status, errors: [Error]()))
    }
    
    public func dismiss() {
        paymentController?.dismiss()
    }
    
    private func getMerchantCapabilitiesFromData(jsMerchantCapabilities: [String]) -> PKMerchantCapability {
        var PKMerchantCapabilityMap = [String: PKMerchantCapability]()
        
        PKMerchantCapabilityMap["supports3DS"] = PKMerchantCapability.threeDSecure
        PKMerchantCapabilityMap["supportsCredit"] = PKMerchantCapability.credit
        PKMerchantCapabilityMap["supportsDebit"] = PKMerchantCapability.debit
        PKMerchantCapabilityMap["supportsEMV"] = PKMerchantCapability.emv
        
        var merchantCapabilities: PKMerchantCapability = [];
        for jsMerchantCapability in jsMerchantCapabilities {
            if (PKMerchantCapabilityMap[jsMerchantCapability] != nil) {
                merchantCapabilities.insert(PKMerchantCapabilityMap[jsMerchantCapability]!)
            }
        }
        
        return merchantCapabilities;
    }
    
    private func getSupportedNetworksFromData(jsSupportedNetworks: [String]) -> [PKPaymentNetwork] {
        var PKPaymentNetworkMap = [String: PKPaymentNetwork]()
        
        PKPaymentNetworkMap["JCB"] = PKPaymentNetwork.JCB
        PKPaymentNetworkMap["amex"] = PKPaymentNetwork.amex
        PKPaymentNetworkMap["cartesBancaires"] = PKPaymentNetwork.cartesBancaires
        PKPaymentNetworkMap["chinaUnionPay"] = PKPaymentNetwork.chinaUnionPay
        PKPaymentNetworkMap["discover"] = PKPaymentNetwork.discover
        PKPaymentNetworkMap["eftpos"] = PKPaymentNetwork.eftpos
        PKPaymentNetworkMap["electron"] = PKPaymentNetwork.electron
        PKPaymentNetworkMap["elo"] = PKPaymentNetwork.elo
        PKPaymentNetworkMap["idCredit"] = PKPaymentNetwork.idCredit
        PKPaymentNetworkMap["interac"] = PKPaymentNetwork.interac
        PKPaymentNetworkMap["mada"] = PKPaymentNetwork.mada
        PKPaymentNetworkMap["maestro"] = PKPaymentNetwork.maestro
        PKPaymentNetworkMap["masterCard"] = PKPaymentNetwork.masterCard
        PKPaymentNetworkMap["privateLabel"] = PKPaymentNetwork.privateLabel
        PKPaymentNetworkMap["quicPay"] = PKPaymentNetwork.quicPay
        PKPaymentNetworkMap["suica"] = PKPaymentNetwork.suica
        PKPaymentNetworkMap["vPay"] = PKPaymentNetwork.vPay
        PKPaymentNetworkMap["visa"] = PKPaymentNetwork.visa
        
        if #available(iOS 14.0, *) {
            PKPaymentNetworkMap["barcode"] = PKPaymentNetwork.barcode
            PKPaymentNetworkMap["girocard"] = PKPaymentNetwork.girocard
        }
        if #available(iOS 14.5, *) {
            PKPaymentNetworkMap["mir"] = PKPaymentNetwork.mir
        }
        if #available(iOS 15.0, *) {
            PKPaymentNetworkMap["nanaco"] = PKPaymentNetwork.nanaco
            PKPaymentNetworkMap["waon"] = PKPaymentNetwork.waon
        }
        if #available(iOS 15.1, *) {
            PKPaymentNetworkMap["dankort"] = PKPaymentNetwork.dankort
        }
        if #available(iOS 16.0, *) {
            PKPaymentNetworkMap["bancomat"] = PKPaymentNetwork.bancomat
            PKPaymentNetworkMap["bancontact"] = PKPaymentNetwork.bancontact
        }
        if #available(iOS 16.4, *) {
            PKPaymentNetworkMap["postFinance"] = PKPaymentNetwork.postFinance
        }
        
        var supportedNetworks: [PKPaymentNetwork] = [];
        
        for supportedNetwork in jsSupportedNetworks {
            if (PKPaymentNetworkMap[supportedNetwork] != nil) {
                supportedNetworks.append(PKPaymentNetworkMap[supportedNetwork]!)
            }
        }
        
        return supportedNetworks;
    }
}

extension PaymentHandler: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        handleCompletion = completion
        do {
            // Create a comprehensive token object with all available information
            var tokenData: [String: Any] = [:]
            
            // Payment data (encrypted payment information)
            var paymentDataJson: [String: Any]? = nil
            if !payment.token.paymentData.isEmpty {
                paymentDataJson = try JSONSerialization.jsonObject(with: payment.token.paymentData, options: []) as? [String: Any]
            }
            tokenData["paymentData"] = paymentDataJson
            
            // Transaction identifier
            tokenData["transactionIdentifier"] = payment.token.transactionIdentifier
            
            // Payment method information
            var paymentMethodInfo: [String: Any] = [:]
            
            if let paymentNetwork = payment.token.paymentMethod.network?.rawValue {
                paymentMethodInfo["network"] = paymentNetwork
            }
            
            paymentMethodInfo["type"] = payment.token.paymentMethod.type.rawValue
            
            if let displayName = payment.token.paymentMethod.displayName {
                paymentMethodInfo["displayName"] = displayName
            }
            
            // Add secure element pass info if available (iOS 13.4+)
            if #available(iOS 13.4, *) {
                if let secureElementPass = payment.token.paymentMethod.secureElementPass {
                    var passInfo: [String: Any] = [:]
                    passInfo["primaryAccountIdentifier"] = secureElementPass.primaryAccountIdentifier
                    passInfo["primaryAccountNumberSuffix"] = secureElementPass.primaryAccountNumberSuffix
                    passInfo["deviceAccountIdentifier"] = secureElementPass.deviceAccountIdentifier
                    passInfo["deviceAccountNumberSuffix"] = secureElementPass.deviceAccountNumberSuffix
                    paymentMethodInfo["secureElementPass"] = passInfo
                }
            }
            
            tokenData["paymentMethod"] = paymentMethodInfo
            
            // Add billing and shipping contact if available
            if let billingContact = payment.billingContact {
                var billingInfo: [String: Any] = [:]
                if let name = billingContact.name {
                    billingInfo["name"] = [
                        "givenName": name.givenName ?? "",
                        "familyName": name.familyName ?? ""
                    ]
                }
                if let postalAddress = billingContact.postalAddress {
                    billingInfo["postalAddress"] = [
                        "street": postalAddress.street,
                        "city": postalAddress.city,
                        "state": postalAddress.state,
                        "postalCode": postalAddress.postalCode,
                        "country": postalAddress.country,
                        "countryCode": postalAddress.isoCountryCode
                    ]
                }
                tokenData["billingContact"] = billingInfo
            }
            
            if let shippingContact = payment.shippingContact {
                var shippingInfo: [String: Any] = [:]
                if let name = shippingContact.name {
                    shippingInfo["name"] = [
                        "givenName": name.givenName ?? "",
                        "familyName": name.familyName ?? ""
                    ]
                }
                if let postalAddress = shippingContact.postalAddress {
                    shippingInfo["postalAddress"] = [
                        "street": postalAddress.street,
                        "city": postalAddress.city,
                        "state": postalAddress.state,
                        "postalCode": postalAddress.postalCode,
                        "country": postalAddress.country,
                        "countryCode": postalAddress.isoCountryCode
                    ]
                }
                tokenData["shippingContact"] = shippingInfo
            }
            
            // Resolve the promise with the complete token data
            promise?.resolve(tokenData)
            promise = nil
        } catch {
            promise?.reject("payment_token_error", "Failed to process payment token: \(error.localizedDescription)")
            promise = nil
        }
    }

    public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
        promise?.reject("dismiss", "closed")
        promise = nil
    }
}
