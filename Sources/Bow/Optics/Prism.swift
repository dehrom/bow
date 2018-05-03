import Foundation

public class ForPPrism {}
public typealias PPrismOf<S, T, A, B> = Kind4<ForPPrism, S, T, A, B>
public typealias PPrismPartial<S, T, A> = Kind3<ForPPrism, S, T, A>

public typealias ForPrism = ForPPrism
public typealias Prism<S, A> = PPrism<S, S, A, A>
public typealias PrismPartial<S> = Kind<ForPrism, S>

public class PPrism<S, T, A, B> : PPrismOf<S, T, A, B> {
    private let getOrModifyFunc : (S) -> Either<T, A>
    private let reverseGetFunc : (B) -> T
    
    public static func +<C, D>(lhs : PPrism<S, T, A, B>, rhs : PPrism<A, B, C, D>) -> PPrism<S, T, C, D> {
        return lhs.compose(rhs)
    }
    
    public static func +<C, D>(lhs : PPrism<S, T, A, B>, rhs : PIso<A, B, C, D>) -> PPrism<S, T, C, D> {
        return lhs.compose(rhs)
    }
    
    public init(getOrModify : @escaping (S) -> Either<T, A>, reverseGet : @escaping (B) -> T) {
        self.getOrModifyFunc = getOrModify
        self.reverseGetFunc = reverseGet
    }
    
    public func getOrModify(_ s : S) -> Either<T, A> {
        return getOrModifyFunc(s)
    }
    
    public func reverseGet(_ b : B) -> T {
        return reverseGet(b)
    }
    
    public func modifyF<Appl, F>(_ applicative : Appl, _ s : S, _ f : @escaping (A) -> Kind<F, B>) -> Kind<F, T> where Appl : Applicative, Appl.F == F {
        return getOrModify(s).fold(applicative.pure,
                                   { a in applicative.map(f(a), self.reverseGet) })
    }
    
    public func liftF<Appl, F>(_ applicative : Appl, _ f : @escaping (A) -> Kind<F, B>) -> (S) -> Kind<F, T> where Appl : Applicative, Appl.F == F {
        return { s in self.modifyF(applicative, s, f) }
    }
    
    public func getMaybe(_ s : S) -> Maybe<A> {
        return getOrModify(s).toMaybe()
    }
    
    public func set(_ s : S, _ b : B) -> T {
        return modify(s, constF(b))
    }
    
    public func setMaybe(_ s : S, _ b : B) -> Maybe<T> {
        return modifyMaybe(s, constF(b))
    }
    
    public func nonEmpty(_ s : S) -> Bool {
        return getMaybe(s).fold(constF(false), constF(true))
    }
    
    public func isEmpty(_ s : S) -> Bool {
        return !nonEmpty(s)
    }
    
    public func first<C>() -> PPrism<(S, C), (T, C), (A, C), (B, C)> {
        return PPrism<(S, C), (T, C), (A, C), (B, C)>(
            getOrModify: { s, c in
                self.getOrModify(s).bimap({ t in (t, c) }, { a in (a, c) })
        },
            reverseGet: { b, c in
                (self.reverseGet(b), c)
        })
    }
    
    public func second<C>() -> PPrism<(C, S), (C, T), (C, A), (C, B)> {
        return PPrism<(C, S), (C, T), (C, A), (C, B)>(
            getOrModify: { c, s in
                self.getOrModify(s).bimap({ t in (c, t) }, { a in (c, a) })
        },
            reverseGet: { c, b in
                (c, self.reverseGet(b))
        })
    }
    
    public func modify(_ s : S, _ f : @escaping (A) -> B) -> T {
        return getOrModify(s).fold(id, { a in self.reverseGet(f(a)) })
    }
    
    public func lift(_ f : @escaping (A) -> B) -> (S) -> T {
        return { s in self.modify(s, f) }
    }
    
    public func modifyMaybe(_ s : S, _ f : @escaping (A) -> B) -> Maybe<T> {
        return getMaybe(s).map { a in reverseGet(f(a)) }
    }
    
    public func liftMaybe(_ f : @escaping (A) -> B) -> (S) -> Maybe<T> {
        return { s in self.modifyMaybe(s, f) }
    }
    
    public func find(_ s : S, _ predicate : @escaping (A) -> Bool) -> Maybe<A> {
        return getMaybe(s).flatMap { a in predicate(a) ? Maybe.some(a) : Maybe.none() }
    }
    
    public func exists(_ s : S, _ predicate : @escaping (A) -> Bool) -> Bool {
        return getMaybe(s).fold(constF(false), predicate)
    }
    
    public func all(_ s : S, _ predicate : @escaping(A) -> Bool) -> Bool {
        return getMaybe(s).fold(constF(true), predicate)
    }
    
    public func left<C>() -> PPrism<Either<S, C>, Either<T, C>, Either<A, C>, Either<B, C>> {
        return PPrism<Either<S, C>, Either<T, C>, Either<A, C>, Either<B, C>>(
            getOrModify: { esc in
                esc.fold({ s in self.getOrModify(s).bimap(Either.left, Either.left) },
                         { c in Either.right(Either.right(c)) })
        },
            reverseGet: { ebc in
                ebc.fold({ b in Either.left(self.reverseGet(b)) }, { c in Either.right(c) })
        })
    }
    
    public func right<C>() -> PPrism<Either<C, S>, Either<C, T>, Either<C, A>, Either<C, B>> {
        return PPrism<Either<C, S>, Either<C, T>, Either<C, A>, Either<C, B>>(
            getOrModify: { ecs in
                ecs.fold({ c in Either.right(Either.left(c)) },
                         { s in self.getOrModify(s).bimap(Either.right, Either.right) })
        },
            reverseGet: { ecb in
                ecb.map(self.reverseGet)
        })
    }
    
    public func compose<C, D>(_ other : PPrism<A, B, C, D>) -> PPrism<S, T, C, D> {
        return PPrism<S, T, C, D>(
            getOrModify: { s in
                self.getOrModify(s).flatMap{ a in other.getOrModify(a).bimap({ b in self.set(s, b) }, id)}
        },
            reverseGet: self.reverseGet <<< other.reverseGet)
    }
    
    public func compose<C, D>(_ other : PIso<A, B, C, D>) -> PPrism<S, T, C, D> {
        return self.compose(other.asPrism())
    }
    
    public func asOptional() -> POptional<S, T, A, B> {
        return POptional(set: self.set, getOrModify: self.getOrModify)
    }
}
