class Operator < ApplicationRecord

  enum role: {
    pedone: 0,
    ufficio: 1,
    laboratorio: 2,
    spedizioni: 3
  }
end
