# Sofamon Wearable Bonding Curve

## Overview
The Sofamon wearable collection is governed by a bonding curve to determine its pricing mechanism dynamically.

### Bonding Curve Equation
The price and supply relationship follows the bonding curve equation:

$Y = \dfrac{X^3}{c}$ 

Where:
- $X$ is the total supply of the wearables, which can range from 0 to the maximum limit of uint256.
- $Y$ is  the cumulative price (in Ethers) of a Sofamon wearable, excluding any creator and protocol fees, for a given supply $X$.
- $c$ is the curve adjustment factor, uniquely set during the creation of each wearable.

### Price Calculation
To calculate the price required for a purchase, the equation used is:

price = $Y(X_2) - Y(X_1)$

- $X_1$ is the current total wearable supply.
- $X_2$ is the new supply after the purchase or sale.

### Wearable Shares
- Each full wearable share is equivalent to 1 Ether (1e18 wei).
- The smallest unit of a wearable share is 0.001 Ether (1e15 wei), allowing for fractional ownership.
- A total of 1000 fractional shares constitutes one full wearable share of the Sofamon collection.
