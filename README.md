# Sofamon Wearable Bonding Curve

## Overview
Sofamon employs a specific bonding curve formula to determine the pricing of user-created wearables. The formula is:

$Y = \dfrac{2000}{X} - 4 + 0.01$ 

Where:
- $X$ represents the total supply of the wearables, ranging from 500 to 1.
- $Y$ indicates the unit price of each wearable (excluding creator and protocol fees) in Ethers, at a given supply $X$.

## Initial Pricing and Supply Dynamics
- Initially, each wearable created in Sofamon has a supply of 500 units.
- The first owner of any wearable must be its creator, buying at the initial price calculated as
$\dfrac{2000}{500}-4+0.01 = 0.01$ ETH. 
- As the supply decreases, the price for purchasing each additional wearable increases.
- The price for the last wearable (when supply reaches 1) will be $\dfrac{2000}{1}-4+0.01 = 1996.01$ ETH.

## Price Calculation Methodology

The `getPrice` function within Sofamon employs specific mathematical approaches for price calculation:

### Harmonic Series Approximation
- The cumulative sum of the bonding curve is calculated using the harmonic series approximation formula:
$H_n = ln(n) + \gamma + \dfrac{1}{2n} - \dfrac{1}{12n^2}$ 
- Here, $\gamma$ represents Euler's constant, approximated as 0.5772156649 in the SofamonWearables implementation.

### Natural Log Approximation
- To approximate the natural logarithm ($ln$), we use the change of base formula:
$ln(x) = log_2(x) \times ln(2)$ 
- In this implementation, $ln(2)$ is approximated as 0.693147180559945309.