# Sofamon Wearable Bonding Curve

## Overview
Sofamon employs two types of bonding curves based on the rarity of the wearables.

For the common wearables (with unlimtied supply), the formula is

$Y = \dfrac{X^2}{16000}$ 

Where:
- $X$ represents the total supply of the wearables, ranging from 1 to the limit of `uint256`.
- $Y$ indicates the unit price of each wearable (excluding creator and protocol fees) in Ethers, at a given supply $X$.

For the exclusive wearables (with limited supply),  the formula is

$Y = \dfrac{100}{X}$ 

Where:
- $X$ represents the total supply of the wearables, ranging from `supply` to 1.
- $Y$ indicates the unit price of each wearable (excluding creator and protocol fees) in Ethers, at a given supply $X$.

## Initial Pricing and Supply Dynamics

For Common Wearables:
- The first owner of the common wearable has to be the creator. Buying at the initial price calculated as
$\dfrac{0^2}{16000} = 0$ ETH. 
- As the supply increases, the price for purchasing each additional wearable increases.
- Technically there is no upper limit of the total supply. 

For Exclusive Wearables:
- Initially, each wearable created in Sofamon has a supply of `supply` units.
- The first owner of exclusive wearable does not have to be the creator. If supply is set to be 100, buying at the initial price calculated as
$\dfrac{100}{100} = 1$ ETH. 
- As the supply decreases, the price for purchasing each additional wearable increases.
- The price for the last wearable (when supply reaches 1) will be $\dfrac{100}{1} = 100$ ETH.
