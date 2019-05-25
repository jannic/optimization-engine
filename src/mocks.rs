use crate::Error;

pub const SOLUTION_A: [f64; 2] = [-0.14895971825577, 0.13345786727339];
pub const SOLUTION_HARD: [f64; 3] = [-0.041123164672281, -0.028440417469206, 0.000167276757790];

pub fn lipschitz_mock(u: &[f64], g: &mut [f64]) -> Result<(), Error> {
    g[0] = 3.0 * u[0];
    g[1] = 2.0 * u[1];
    g[2] = 4.5;
    Ok(())
}

pub fn void_cost(_u: &[f64], _cost: &mut f64) -> Result<(), Error> {
    Ok(())
}

pub fn void_gradient(_u: &[f64], _grad: &mut [f64]) -> Result<(), Error> {
    Ok(())
}

pub fn my_cost(u: &[f64], cost: &mut f64) -> Result<(), Error> {
    *cost = 0.5 * (u[0].powi(2) + 2. * u[1].powi(2) + 2.0 * u[0] * u[1]) + u[0] - u[1] + 3.0;
    Ok(())
}

pub fn my_gradient(u: &[f64], grad: &mut [f64]) -> Result<(), Error> {
    grad[0] = u[0] + u[1] + 1.0;
    grad[1] = u[0] + 2. * u[1] - 1.0;
    Ok(())
}

#[allow(dead_code)]
pub fn rosenbrock_cost(a: f64, b: f64, u: &[f64]) -> f64 {
    (a - u[0]).powi(2) + b * (u[1] - u[0].powi(2)).powi(2)
}

#[allow(dead_code)]
pub fn rosenbrock_grad(a: f64, b: f64, u: &[f64], grad: &mut [f64]) {
    grad[0] = 2.0 * u[0] - 2.0 * a - 4.0 * b * u[0] * (-u[0].powi(2) + u[1]);
    grad[1] = b * (-2.0 * u[0].powi(2) + 2.0 * u[1]);
}

pub fn hard_quadratic_cost(u: &[f64], cost: &mut f64) -> Result<(), Error> {
    *cost = (4. * u[0].powi(2)) / 2.
        + 5.5 * u[1].powi(2)
        + 500.5 * u[2].powi(2)
        + 5. * u[0] * u[1]
        + 25. * u[0] * u[2]
        + 5. * u[1] * u[2]
        + u[0]
        + u[1]
        + u[2];
    Ok(())
}

pub fn hard_quadratic_gradient(u: &[f64], grad: &mut [f64]) -> Result<(), Error> {
    // norm(Hessian) = 1000.653 (Lipschitz gradient)
    grad[0] = 4. * u[0] + 5. * u[1] + 25. * u[2] + 1.;
    grad[1] = 5. * u[0] + 11. * u[1] + 5. * u[2] + 1.;
    grad[2] = 25. * u[0] + 5. * u[1] + 1001. * u[2] + 1.;
    Ok(())
}

#[cfg(test)]
mod tests {

    use super::*;

    #[test]
    fn t_mock_hard() {
        let x = [1.5, 2.6, -3.7];
        let mut df = [0.0; 3];
        let mut cost = 0.0;
        assert_eq!(Ok(()), hard_quadratic_cost(&x, &mut cost));

        unit_test_utils::assert_nearly_equal(6726.575, cost, 1e-8, 1e-10, "cost");

        assert_eq!(Ok(()), hard_quadratic_gradient(&x, &mut df));
        unit_test_utils::assert_nearly_equal_array(
            &[-72.5, 18.6, -3652.2],
            &df,
            1e-6,
            1e-6,
            "grad",
        );
    }
}