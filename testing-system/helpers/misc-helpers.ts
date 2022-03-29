import { expect } from 'chai';
import { BigNumber as BN, BigNumberish } from 'ethers';

export function approxBigNumber(
  _actual: BigNumberish,
  _expected: BigNumberish,
  _delta: BigNumberish,
  log: boolean = false
) {
  let actual: BN = BN.from(_actual);
  let expected: BN = BN.from(_expected);
  let delta: BN = BN.from(_delta);

  var diff = expected.sub(actual);
  if (diff.lt(0)) {
    diff = diff.mul(-1);
  }
  if (diff.lte(delta) == false) {
    expect(
      diff.lte(delta),
      `expecting: ${expected.toString()}, received: ${actual.toString()}, diff: ${diff.toString()}, allowedDelta: ${delta.toString()}`
    ).to.be.true;
  } else {
    if (log) {
      console.log(
        `expecting: ${expected.toString()}, received: ${actual.toString()}, diff: ${diff.toString()}, allowedDelta: ${delta.toString()}`
      );
    }
  }
}

export function approxByPercent(_actual: BigNumberish, _expected: BigNumberish, _proportion: BigNumberish = 10 ** 5) {
  let actual: BN = BN.from(_actual);
  let expected: BN = BN.from(_expected);
  let minVal = actual.lt(expected) ? actual : expected;
  approxBigNumber(actual, expected, minVal.div(_proportion));
}

export function minBN(_a: BigNumberish, _b: BigNumberish) {
  let a = BN.from(_a);
  let b = BN.from(_b);
  return a.lt(b) ? a : b;
}

/**
 * @returns one random integers in [l, r)
 */
export function random(l: number, r: number) {
  return Math.floor(Math.random() * (r - l) + l);
}
