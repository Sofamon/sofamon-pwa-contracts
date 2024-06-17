# Sofamon Wearable Bonding Curve

## Overview
The Sofamon wearable collection is governed by a bonding curve to determine its pricing mechanism dynamically.

### Bonding Curve Equation
The price and supply relationship follows the bonding curve equation:

$Y = \dfrac{c_{supply} \times c_{price}}{c_{supply}-x}-\dfrac{c_{supply} \times c_{price}}{c_{supply}} - \dfrac{c_{initialPrice}}{1000} \times x$ 

Where:
- $X$ is the total supply of the wearables, which can range from 0 to $c_{supply}$ but never reach $c_{supply}$.
- $Y$ is  the cumulative price (in Ethers) of a Sofamon wearable, excluding any creator and protocol fees, for a given supply $X$.
- $c_{supply}$ is the total supply of the wearable, and the asymptote of the bonding curve. 
- $c_{price}$ is the curve factor, uniquely set during the creation of each wearable based on wearable's rarity and supply.
- $c_{initialPrice}$ is the initial price adjustment factor (a horizontal shift of the derivative of the bonding curve) to help determine the initial price of the sofamon wearable. 

### Price Calculation
To calculate the price required for a purchase, the equation used is:

price = $Y(X_2) - Y(X_1)$

- $X_1$ is the current total wearable supply.
- $X_2$ is the new supply after the purchase or sale.

### Wearable Shares
- Each full wearable share is equivalent to 1 Ether (1e18 wei).
- The smallest unit of a wearable share is 0.001 Ether (1e15 wei), allowing for fractional ownership.
- A total of 1000 fractional shares constitutes one full wearable share of the Sofamon collection.

## Note

### 4/18/2024 - Update made since the second audit:
- updated the `_buyWearables` function. instead of revert with the error `ExcessivePayment`, we introduced a refund logic, which serves as a max slippage to mitigate transactions failed errors due to infuccicient payment when multiple users try to make purchases as the same time during the pre-sale. Code update: https://github.com/Sofamon/sofamon-pwa-contracts/commit/6af00565d60b01a6a3e890e2c2c1bcb386588c18
- added a script `UpgradeSofamonWearables.sol` to upgrade the implementation contract with the new refund logic. the new implementation contract's name remains the name, `SofamonWearables`. 


### 3/8/2024 - Update made since the first audit:
- updated the bonding curve with an asymptote (the supply cap) for each wearable. instead of `curveAdjustmentFactor`, we introduced `supplyFactor` (the supply cap) and the `curveFactor` (the adjustment factor) to the new bonding curve.
- added an `wearableOperator` role and only the `wearableOperator` can create wearable and change the wearable sale state. we introduced this primarily for access control in our backend. the contract owner's private key won't be exposed to our backend, but the operator and signer will. 
- renamed old `operator` to `pointsOperator` for better clarity.
- introduced setter function `setWearableOperator` for `wearableOperator`.
- introduced setter function `setBlastGovernor` and `setBlastPointsOperator` for Blast's governor and Blast points operator. 
- introduced a `creator` param when creating a new wearable.
- renamed `createSigner` to `wearableSigner`.
