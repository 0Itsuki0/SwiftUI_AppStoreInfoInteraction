
import SwiftUI
import StoreKit

struct ContentView: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.displayStoreKitMessage) private var displayStoreKitMessage
    @Environment(\.openURL) private var openURL

    @State private var ageRatingCode: Int? = nil
    @State private var storeFront: Storefront? = nil
    @State private var appTransaction: AppTransaction? = nil
    
    private let appURLString = "https://apps.apple.com/us/app/aibrowserbyitsuki/id6754548157"
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Get Information & make interaction")
                        .listRowBackground(Color.clear)
                        .listRowInsets(.all, 0)
                        .listRowInsets(.leading, 8)
                        .foregroundStyle(.secondary)
                }
                .listSectionMargins(.vertical, 0)
                
                
                Section("Current App Store StoreFront") {
                    if let storeFront {
                        row("Id", storeFront.id)
                        row("Country code", storeFront.countryCode)
                        row("Currency", "\(storeFront.currency, default: "Unknown")")
                    } else {
                        Text("App Store storefront information unavailable.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Downloaded App Information") {
                    row("Age Rating", "\(self.ageRatingCode, default: "unknown")")

                    if let appTransaction {
                        
                        row("Id", appTransaction.appTransactionID)
                        row("Bundle Id", appTransaction.bundleID)
                        row("Downloaded on", appTransaction.originalPurchaseDate.ISO8601Format())
                        row("Original Version", appTransaction.originalAppVersion)
                        row("Current Version", appTransaction.appVersion)
                        
                    } else {
                        Text("App Transaction Info not available.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Request Review") {
                    Button(action: {
                        requestReview()
                    }, label: {
                        Text("With `requestReview`")
                    })
                    
                    
                    if let url = URL(string: "\(appURLString)?action=write-review"),
                       UIApplication.shared.canOpenURL(url) {
                        Button(action: {
                            openURL(url)
                        }, label: {
                            Text("With `openURL`")
                        })
                    }

                }
                
            }
            .contentMargins(.top, 0)
            .navigationTitle("AppStore Interaction")
            .task {
                // app age rating
                let ageRatingCode = await AppStore.ageRatingCode
                self.ageRatingCode = ageRatingCode == 0 ? nil : ageRatingCode
                
                // get current storefront
                self.storeFront = await Storefront.current
                // watch for storefront changes
                for await update in Storefront.updates {
                    print("storefront updated: \(update)")
                    self.storeFront = update
                }
                
                // app store message
                for await message in Message.messages {
                    print("message received: \(message)")
                    switch message.reason {
                    case .billingIssue, .priceIncreaseConsent, .winBackOffer:
                        do {
                            try displayStoreKitMessage(message)
                        } catch(let error) {
                            print("error displaying message: \(error)")
                        }
                        break
                    case .generic:
                        break
                    default:
                        break
                    }
                }
                
                
                // customer’s purchase info of the app
                // ex: when if the app first downloaded, the original version, current version, and etc.
                //
                // NOTE:
                // calling AppTransaction.shared will prompt user for login.
                //
                // if the The shared property throws an error or returns an unverified result, use AppTransaction.refresh() to refresh the app transaction information
                do {
                    let verificationResult = try await AppTransaction.shared
                    switch verificationResult {
                    case .verified(let appTransaction):
                        print(appTransaction.bundleID)
                    case .unverified(_, let verificationError):
                        print("unverified app transaction: \(verificationError)")
                    }
                } catch(let error) {
                    print("error: \(error)")
                }

            }

            
        }
    }
    
    private func row(_ title: String, _ content: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(content)
                .foregroundStyle(.secondary)
        }
    }
    
    
}

#Preview {
    ContentView()
}
