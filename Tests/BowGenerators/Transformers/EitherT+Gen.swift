import Bow
import SwiftCheck

// MARK: Generator for Property-based Testing

extension EitherT: Arbitrary where F: ArbitraryK, A: Arbitrary, B: Arbitrary {
    public static var arbitrary: Gen<EitherT<F, A, B>> {
        Gen.from(EitherTPartial.generate >>> EitherT.fix)
    }
}

// MARK: Instance of ArbitraryK for EitherT

extension EitherTPartial: ArbitraryK where F: ArbitraryK, L: Arbitrary {
    public static func generate<A: Arbitrary>() -> EitherTOf<F, L, A> {
        EitherT(F.generate())
    }
}
