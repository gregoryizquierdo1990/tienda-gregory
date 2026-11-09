-- Migración 63: Eliminar cuenta madre no renovada villanetservi+ext-ah4@gmail.com
DO $$
DECLARE
  v_mother_id uuid;
BEGIN
  SELECT id INTO v_mother_id FROM public.mother_accounts WHERE lower(trim(correo)) = lower('villanetservi+ext-ah4@gmail.com');

  IF v_mother_id IS NOT NULL THEN
    -- Desvincular órdenes históricas de los perfiles de esta cuenta madre
    UPDATE public.orders
    SET profile_id = NULL
    WHERE profile_id IN (SELECT id FROM public.profiles_inventory WHERE mother_id = v_mother_id);

    -- Eliminar perfiles asociados en profiles_inventory
    DELETE FROM public.profiles_inventory WHERE mother_id = v_mother_id;

    -- Eliminar la cuenta madre
    DELETE FROM public.mother_accounts WHERE id = v_mother_id;
  END IF;
END $$;
