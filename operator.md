# Operators

1.  I need entities like Company_operator, Supplier, Customer . The company operators work in the ap and have access authentication with devise

Different types of operators for the company / 1 Godlike , and others with ad hoc abilities
2.  There must be a dashboard for the godlike in which can assign and remove abilities
3.  roles are ufficio, lab, magazzino , a operator can have multiple roles
4. Operator - not sure if has to be a user or a new model that can use devise   tell me whch strategy is better. Can it be a User with abilities? godlike etc, we need a lookup table i guess

at system, there are already 2 or 3 users , the idea if scaling is to use the User model for Customers, Suppliers, Operators  // and a lookup for abilities of the operators

	 