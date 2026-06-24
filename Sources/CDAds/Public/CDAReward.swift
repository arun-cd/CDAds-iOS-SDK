import Foundation

/// The reward granted to the user after completing a rewarded video.
public struct CDAReward {
    public let currencyType: String
    public let amount: Int

    public init(currencyType: String, amount: Int) {
        self.currencyType = currencyType
        self.amount = amount
    }
}
