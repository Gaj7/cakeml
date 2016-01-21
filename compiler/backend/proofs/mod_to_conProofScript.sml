open preamble
     semanticPrimitivesTheory evalPropsTheory
     mod_to_conTheory conPropsTheory;

val _ = new_theory "mod_to_conProof";

(* TODO: move *)

val with_same_v = Q.store_thm("with_same_v[simp]",
  `((env:conSem$environment) with v := env.v) = env`,
  rw[conSemTheory.environment_component_equality])

(* -- *)

(* invariants *)

val _ = type_abbrev("gtagenv",``:conN # tid_or_exn |-> num # num``)

val has_exns_def = Define `
  has_exns gtagenv ⇔
    FLOOKUP gtagenv ("Subscript", TypeExn (Short "Subscript")) = SOME (subscript_tag,0:num) ∧
    FLOOKUP gtagenv ("Bind", TypeExn (Short "Bind")) = SOME (bind_tag,0) ∧
    FLOOKUP gtagenv ("Chr", TypeExn (Short "Chr")) = SOME (chr_tag,0) ∧
    FLOOKUP gtagenv ("Div", TypeExn (Short "Div")) = SOME (div_tag,0) ∧
    FLOOKUP gtagenv ("Eq", TypeExn (Short "Eq")) = SOME (eq_tag,0)`;

val has_lists_def = Define `
  has_lists gtagenv ⇔
    FLOOKUP gtagenv ("nil", TypeId (Short "list")) = SOME (nil_tag,0:num) ∧
    FLOOKUP gtagenv ("::", TypeId (Short "list")) = SOME (cons_tag,2)`;

val has_bools_def = Define`
  has_bools gtagenv ⇔
    FLOOKUP gtagenv ("true", TypeId(Short"bool")) = SOME (true_tag,0:num) ∧
    FLOOKUP gtagenv ("false", TypeId(Short"bool")) = SOME (false_tag,0:num)`

val gtagenv_wf_def = Define `
  gtagenv_wf gtagenv ⇔
    has_exns gtagenv ∧
    has_bools gtagenv ∧
    has_lists gtagenv ∧
    (∀t1 t2 tag l cn cn'.
      same_tid t1 t2 ∧
      FLOOKUP gtagenv (cn,t1) = SOME (tag,l) ∧
      FLOOKUP gtagenv (cn',t2) = SOME (tag,l) ⇒
      cn = cn' ∧ t1 = t2) ∧
    (∀t cn. (cn,TypeExn t) ∈ FDOM gtagenv ⇒ cn = id_to_n t)`;

val envC_tagged_def = Define `
  envC_tagged (envC:env_ctor) (tagenv:tag_env) gtagenv =
    (!cn num_args t.
      lookup_alist_mod_env cn envC = SOME (num_args, t)
      ⇒
      ?tag.
        lookup_tag_env (SOME cn) tagenv = SOME (tag, t) ∧
        FLOOKUP gtagenv (id_to_n cn, t) = SOME (tag,num_args))`;

val flat_envC_tagged_def = Define `
 flat_envC_tagged (envC:flat_env_ctor) (tagenv:flat_tag_env) gtagenv ⇔
   ∀cn num_args t.
     ALOOKUP envC cn = SOME (num_args,t) ⇒
     ∃tag.
       lookup_tag_flat cn tagenv = SOME (tag,t) ∧
       FLOOKUP gtagenv (cn,t) = SOME (tag,num_args)`

val envC_tagged_flat_envC_tagged = Q.prove(
  `envC_tagged envC tagenv gtagenv ⇒
   flat_envC_tagged (SND envC) (SND tagenv) gtagenv`,
  rw[envC_tagged_def,flat_envC_tagged_def] >>
  first_x_assum(qspec_then`Short cn`mp_tac) >>
  Cases_on`envC`>>simp[lookup_alist_mod_env_def] >>
  Cases_on`tagenv`>>fs[lookup_tag_env_def,astTheory.id_to_n_def])

val next_inv_def = Define`
  next_inv tids next (gtagenv:gtagenv) ⇔
    (∀cn t tag a.
       FLOOKUP gtagenv (cn,TypeExn t) = SOME (tag,a) ⇒
       ∃max. lookup a next = SOME max ∧ tag < max)
    ∧ IMAGE SND (FDOM gtagenv) ⊆ tids`

val next_inv_tids_subset = prove(
  ``s1 ⊆ s2 ∧ next_inv s1 st g ⇒ next_inv s2 st g``,
  rw[next_inv_def] >>
  metis_tac[SUBSET_TRANS])

val exhaustive_env_correct_def = Define `
  exhaustive_env_correct (exh:exh_ctors_env) (gtagenv:gtagenv) ⇔
    (∀t. t ∈ FRANGE exh ⇒ wf t) ∧
    (!t.
       (?cn. (cn, TypeId t) ∈ FDOM gtagenv)
       ⇒
       ?tags.
         FLOOKUP exh t = SOME tags ∧
         (!cn tag l. FLOOKUP gtagenv (cn,TypeId t) = SOME (tag,l)
           ⇒
           ∃max. lookup l tags = SOME max ∧ tag < max))`;

val cenv_inv_def = Define `
  cenv_inv envC exh tagenv gtagenv ⇔
   envC_tagged envC tagenv gtagenv ∧
   exhaustive_env_correct exh gtagenv ∧
   gtagenv_wf gtagenv`;

(* weakenings *)

val gtagenv_weak_def = Define `
  gtagenv_weak gtagenv1 gtagenv2 ⇔
    gtagenv1 SUBMAP gtagenv2 ∧
    (* Don't weaken by adding a constructor to an existing type. This is necessary for pattern exhaustiveness checking. *)
    (!t. (?cn. (cn,t) ∈ FDOM gtagenv1) ⇒ !cn. (cn,t) ∈ FDOM gtagenv2 ⇒ (cn,t) ∈ FDOM gtagenv1) ∧
    (!t1 t2 tag cn cn' l.
       same_tid t1 t2 ∧
       FLOOKUP gtagenv2 (cn,t1) = SOME (tag,l) ∧
       FLOOKUP gtagenv2 (cn',t2) = SOME (tag,l)
       ⇒
       cn = cn' ∧ t1 = t2) ∧
    (∀t cn.  (cn,TypeExn t) ∈ FDOM gtagenv2 ⇒ cn = id_to_n t)`;

val gtagenv_weak_refl = Q.prove (
  `!gtagenv envC tagenv.
    gtagenv_wf gtagenv
    ⇒
    gtagenv_weak gtagenv gtagenv`,
  rw [gtagenv_weak_def] >>
  metis_tac [SUBMAP_REFL, gtagenv_wf_def]);

val gtagenv_weak_trans = Q.prove (
  `!gtagenv1 gtagenv2 gtagenv3.
    gtagenv_weak gtagenv1 gtagenv2 ∧
    gtagenv_weak gtagenv2 gtagenv3
    ⇒
    gtagenv_weak gtagenv1 gtagenv3`,
  rw [gtagenv_weak_def] >>
  fs [FLOOKUP_DEF, SUBMAP_DEF] >>
  metis_tac []);

val gtagenv' = ``(gtagenv':gtagenv)``

val weakened_exh_def = Define`
  ((weakened_exh ^gtagenv' (exh:exh_ctors_env)):exh_ctors_env) =
    FUN_FMAP (λt.
      union
      (fromAList (SET_TO_LIST ({(l,1+(MAX_SET {tag | ∃cn. FLOOKUP ^gtagenv' (cn, TypeId t) = SOME (tag,l)}))
                               | l | ∃cn tag. FLOOKUP ^gtagenv' (cn, TypeId t) = SOME (tag,l)})))
      (case FLOOKUP exh t of NONE => LN | SOME tags => tags))
      { t | ∃cn. (cn, TypeId t) ∈ FDOM gtagenv' }`

val FINITE_weakened_exh_dom = prove(
  ``FINITE {t | ∃cn. (cn,TypeId t) ∈ FDOM ^gtagenv'}``,
  qmatch_abbrev_tac`FINITE P` >>
  qsuff_tac`∃f. P ⊆ IMAGE f (FDOM gtagenv')` >-
    metis_tac[IMAGE_FINITE,SUBSET_FINITE,FDOM_FINITE] >>
  simp[Abbr`P`,SUBSET_DEF] >>
  qexists_tac`λx. @y. SND x = TypeId y` >>
  rw[EXISTS_PROD] >> metis_tac[tid_or_exn_11]);

val FDOM_weakened_exh = prove(
  ``FDOM (weakened_exh ^gtagenv' exh) = { t | ∃cn. (cn, TypeId t) ∈ FDOM gtagenv' }``,
  rw[weakened_exh_def] >>
  (FUN_FMAP_DEF |> SPEC_ALL |> UNDISCH |> CONJUNCT1 |> DISCH_ALL |> GEN_ALL |> match_mp_tac) >>
  rw[FINITE_weakened_exh_dom]);

val FLOOKUP_weakened_exh_imp = prove(
  ``(∀tags. tags ∈ FRANGE exh ⇒ wf tags) ∧
    (FLOOKUP (weakened_exh ^gtagenv' exh) t = SOME tags) ⇒
    wf tags ∧
    (∀a max. lookup a tags = SOME max ⇒
             (∃cn tag. FLOOKUP gtagenv' (cn, TypeId t) = SOME (tag,a) ∧ tag < max) ∨
             (∃tags'. FLOOKUP exh t = SOME tags'  ∧ lookup a tags' = SOME max)) ∧
    (∀cn tag a.
      FLOOKUP gtagenv' (cn, TypeId t) = SOME (tag,a) ⇒
      ∃max. lookup a tags = SOME max ∧ tag < max)``,
  simp[Once FLOOKUP_DEF,FDOM_weakened_exh] >>
  strip_tac >> BasicProvers.VAR_EQ_TAC >>
  simp[weakened_exh_def] >>
  qmatch_abbrev_tac`wf (FUN_FMAP f X ' t) ∧ Z` >>
  strip_assume_tac(
    Q.ISPEC`f:string id -> num spt`(MATCH_MP FUN_FMAP_DEF FINITE_weakened_exh_dom)) >>
  fs[Abbr`X`,PULL_EXISTS,Abbr`Z`] >>
  res_tac >>
  pop_assum (SUBST1_TAC) >>
  simp[Abbr`f`] >>
  conj_tac >- (
    match_mp_tac sptreeTheory.wf_union >>
    conj_tac >- rw[sptreeTheory.wf_fromAList] >>
    BasicProvers.CASE_TAC >-
      rw[sptreeTheory.wf_def] >>
    fs[IN_FRANGE_FLOOKUP,PULL_EXISTS] >>
    PROVE_TAC[]) >>
  simp[sptreeTheory.lookup_union,sptreeTheory.lookup_fromAList] >>
  qpat_abbrev_tac `s:(num#num) set = X` >>
  `FINITE s` by (
    simp[Abbr`s`,FLOOKUP_DEF] >>
    qmatch_abbrev_tac`FINITE P` >>
    qsuff_tac`∃f. P ⊆ IMAGE f (FDOM gtagenv')` >-
      metis_tac[IMAGE_FINITE,SUBSET_FINITE,FDOM_FINITE] >>
    `∃f. ∀x. x ∈ P ⇒ ∃y. y ∈ FDOM gtagenv' ∧ f y = x` by (
      simp[Abbr`P`,PULL_EXISTS] >>
      qho_match_abbrev_tac`∃f. ∀l cn' tag. Y cn' ∈ FDOM gtagenv' ∧ Z cn' tag l ⇒ ∃y. A y ∧ f y = X l cn' tag` >>
      qexists_tac`λp. X (SND (gtagenv' ' p)) (FST p) (FST (gtagenv' ' p))` >>
      simp[EXISTS_PROD,Abbr`Y`,Abbr`Z`] >>
      metis_tac[FST,SND] ) >>
    qexists_tac`f` >>
    simp[SUBSET_DEF] >>
    metis_tac[]) >>
  pop_assum(strip_assume_tac o MATCH_MP (GSYM SET_TO_LIST_IN_MEM)) >>
  conj_tac >- (
    rpt gen_tac >>
    rpt BasicProvers.CASE_TAC >> simp[CONJUNCT1 sptreeTheory.lookup_def] >>
    imp_res_tac ALOOKUP_MEM >>
    rfs[Abbr`s`] >> rw[] >>
    TRY disj1_tac >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    qho_match_abbrev_tac`tag < (MAX_SET P) + 1` >>
    qho_match_abbrev_tac`Q (MAX_SET P)` >>
    match_mp_tac MAX_SET_ELIM >>
    `P ⊆ IMAGE FST (FRANGE gtagenv')` by (
      simp[Abbr`P`,SUBSET_DEF,IN_FRANGE_FLOOKUP,EXISTS_PROD] >>
      metis_tac[] ) >>
    (conj_tac >- metis_tac[FINITE_FRANGE,SUBSET_FINITE,IMAGE_FINITE]) >>
    (conj_tac >- ( simp[Abbr`P`,EXTENSION] >> metis_tac[] )) >>
    simp[Abbr`P`,Abbr`Q`,PULL_EXISTS] >>
    rw[] >> res_tac >> simp[]) >>
  rpt gen_tac >> strip_tac >>
  rpt BasicProvers.CASE_TAC >> simp[CONJUNCT1 sptreeTheory.lookup_def] >>
  TRY(
    CHANGED_TAC(imp_res_tac ALOOKUP_FAILS) >>
    rfs[Abbr`s`] >>
    metis_tac[]) >>
  imp_res_tac ALOOKUP_MEM >> rfs[Abbr`s`] >>
  qho_match_abbrev_tac`tag < (MAX_SET P) + 1` >>
  qho_match_abbrev_tac`Q (MAX_SET P)` >>
  match_mp_tac MAX_SET_ELIM >>
  `P ⊆ IMAGE FST (FRANGE gtagenv')` by (
    simp[Abbr`P`,SUBSET_DEF,IN_FRANGE_FLOOKUP,EXISTS_PROD] >>
    metis_tac[] ) >>
  (conj_tac >- metis_tac[FINITE_FRANGE,SUBSET_FINITE,IMAGE_FINITE]) >>
  (conj_tac >- ( simp[Abbr`P`,EXTENSION] >> metis_tac[] )) >>
  simp[Abbr`P`,Abbr`Q`,PULL_EXISTS] >>
  rw[] >> res_tac >> simp[])

val exhaustive_env_weak = Q.prove (
  `!gtagenv gtagenv' exh.
      exhaustive_env_correct exh gtagenv ∧
      gtagenv_weak gtagenv ^gtagenv'
      ⇒
      ?exh'.
        exhaustive_env_correct exh' gtagenv'`,
  rw [gtagenv_weak_def, exhaustive_env_correct_def] >>
  qexists_tac `weakened_exh gtagenv' exh ⊌ exh` >>
  conj_tac >- (
    ho_match_mp_tac IN_FRANGE_FUNION_suff >> simp[] >>
    rw[IN_FRANGE_FLOOKUP] >> imp_res_tac FLOOKUP_weakened_exh_imp) >>
  rw [] >>
  cases_on `?cn. (cn,TypeId t) ∈ FDOM gtagenv` >>
  res_tac >>
  fs [] >>
  rw []
  >- (`(cn,TypeId t) ∈ FDOM gtagenv` by metis_tac [] >>
      `?tags. FLOOKUP exh t = SOME tags ∧
              ∀cn tag l. FLOOKUP gtagenv (cn,TypeId t) = SOME (tag,l) ⇒
              ∃max. lookup l tags = SOME max ∧ tag < max` by metis_tac [] >>
      fs [FLOOKUP_FUNION] >>
      Cases_on `FLOOKUP (weakened_exh gtagenv' exh) t` >> simp[] >- (
        fs[FLOOKUP_DEF,FDOM_weakened_exh,PULL_EXISTS] ) >>
      imp_res_tac FLOOKUP_weakened_exh_imp >>
      rw [] >>
      metis_tac[]) >>
   simp[FLOOKUP_FUNION] >>
   BasicProvers.CASE_TAC >- (
     fs[FLOOKUP_DEF,FDOM_weakened_exh] ) >>
   imp_res_tac FLOOKUP_weakened_exh_imp >>
   metis_tac[]);

val next_weak_def = Define`
  next_weak next1 next2 ⇔
    ∀a max1. lookup a next1 = SOME (max1:num) ⇒
      ∃max2. lookup a next2 = SOME max2 ∧ max1 ≤ max2`

val next_weak_trans = store_thm("next_weak_trans",
  ``next_weak n1 n2 ∧ next_weak n2 n3 ⇒ next_weak n1 n3``,
  rw[next_weak_def] >> res_tac >> rw[] >>
  res_tac >> rw[] >> simp[])

val exh_weak_def = Define`
  exh_weak (exh:exh_ctors_env) (exh':exh_ctors_env) ⇔
    ∀tid m. FLOOKUP exh tid = SOME m ⇒
      ∃m'. FLOOKUP exh' tid = SOME m' ∧
        ∀a x. lookup a m = SOME x ⇒
           ∃y. lookup a m' = SOME y ∧ x ≤ y`

val exh_weak_refl = store_thm("exh_weak_refl[simp]",
  ``exh_weak exh exh``,
  rw[exh_weak_def])

val exh_weak_trans = store_thm("exh_weak_trans",
  ``exh_weak exh1 exh2 ∧ exh_weak exh2 exh3 ⇒ exh_weak exh1 exh3``,
  rw[exh_weak_def] >>
  res_tac >> res_tac >> rw[] >> fs[] >> rw[] >>
  res_tac >> fs[] >> rw[] >> res_tac >> rw[] >> simp[])

val exh_wf_def = Define`
  exh_wf exh = ∀t. t ∈ FRANGE exh ⇒ wf t`

val exhaustive_env_correct_exh_weak = store_thm("exhaustive_env_correct_exh_weak",
  ``exhaustive_env_correct exh gtagenv ∧
    exh_weak exh exh' ∧ exh_wf exh' (* ∧ FDOM exh' ⊆ { t | TypeId t ∈ IMAGE SND (FDOM gtagenv) } *) ⇒
    exhaustive_env_correct exh' gtagenv``,
  rw[exhaustive_env_correct_def] >>
  fs[PULL_EXISTS,exh_weak_def,exh_wf_def] >>
  res_tac >> res_tac >> rw[] >>
  res_tac >> fs[] >> rw[] >>
  res_tac >> fs[] >> rw[] >> simp[])

val envC_tagged_extend = prove(
  ``envC_tagged envC tagenv gtagenv ∧
    flat_envC_tagged cenv acc gtagenv' ∧
    FDOM acc = set (MAP FST cenv) ∧
    gtagenv_weak gtagenv gtagenv'
    ⇒
    envC_tagged (merge_alist_mod_env (mod_cenv mn cenv) envC)
      (mod_tagenv mn acc tagenv) gtagenv'``,
  PairCases_on`envC` >>
  PairCases_on`tagenv` >>
  simp[envC_tagged_def] >>
  Cases_on`mn`>>simp[modSemTheory.mod_cenv_def,mod_tagenv_def,merge_alist_mod_env_def,flat_envC_tagged_def] >- (
    rw[lookup_alist_mod_env_def,lookup_tag_env_def,lookup_tag_flat_def,FLOOKUP_FUNION,ALOOKUP_APPEND] >>
    first_x_assum(qspec_then`cn`mp_tac) >>
    pop_assum mp_tac >>
    BasicProvers.CASE_TAC >> fs[] >- (
      BasicProvers.CASE_TAC >> fs[] >- (
        imp_res_tac ALOOKUP_NONE >>
        `FLOOKUP acc a = NONE` by (
          fs[FLOOKUP_DEF] ) >>
        simp[] >> strip_tac >>
        fs[gtagenv_weak_def] >>
        metis_tac[FLOOKUP_SUBMAP] ) >>
      strip_tac >> BasicProvers.VAR_EQ_TAC >>
      first_x_assum(fn th => first_assum (mp_tac o MATCH_MP th)) >>
      simp[astTheory.id_to_n_def] >> strip_tac >>
      BasicProvers.CASE_TAC >> simp[] >- (
        BasicProvers.CASE_TAC >> fs[] >>
        BasicProvers.CASE_TAC >> fs[] ) >>
      BasicProvers.CASE_TAC >> simp[] >>
      rw[] >> fs[] >>
      BasicProvers.CASE_TAC >> fs[] ) >>
    BasicProvers.CASE_TAC >>
    strip_tac >>
    fs[gtagenv_weak_def] >>
    metis_tac[FLOOKUP_SUBMAP] ) >>
  simp[lookup_alist_mod_env_def,lookup_tag_flat_def,lookup_tag_env_def,FLOOKUP_UPDATE] >>
  rw[] >>
  first_x_assum(qspec_then`cn`mp_tac) >>
  BasicProvers.CASE_TAC >> fs[] >- (
    fs[gtagenv_weak_def] >>
    metis_tac[FLOOKUP_SUBMAP] ) >>
  rw[] >> fs[FLOOKUP_UPDATE, FLOOKUP_FUNION] >- (
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    simp[astTheory.id_to_n_def] >> rw[]  >>
    BasicProvers.CASE_TAC >> fs[] ) >>
  pop_assum mp_tac >>
  BasicProvers.CASE_TAC >> fs[] >>
  metis_tac[gtagenv_weak_def,FLOOKUP_SUBMAP]);

(* value relation *)

val (v_rel_rules, v_rel_ind, v_rel_cases) = Hol_reln `
  (!gtagenv lit.
    v_rel gtagenv (Litv lit) (Litv lit)) ∧
  (!gtagenv vs vs'.
    vs_rel gtagenv vs vs'
    ⇒
    v_rel gtagenv (Conv NONE vs) (Conv NONE vs')) ∧
  (!gtagenv cn tn tag vs vs'.
    FLOOKUP gtagenv (cn,tn) = SOME (tag, LENGTH vs) ∧
    vs_rel gtagenv vs vs'
    ⇒
    v_rel gtagenv (Conv (SOME (cn,tn)) vs) (Conv (SOME (tag,tn)) vs')) ∧
  (!gtagenv env x e env_i2 envC exh tagenv.
    env_rel gtagenv env env_i2 ∧
    cenv_inv envC exh tagenv gtagenv
    ⇒
    v_rel gtagenv (Closure (envC,env) x e) (Closure env_i2 x (compile_exp tagenv e))) ∧
  (!gtagenv env funs x envC env_i2 exh tagenv.
    env_rel gtagenv env env_i2 ∧
    cenv_inv envC exh tagenv gtagenv
    ⇒
    v_rel gtagenv (Recclosure (envC,env) funs x) (Recclosure env_i2 (compile_funs tagenv funs) x)) ∧
  (!gtagenv loc.
    v_rel gtagenv (Loc loc) (Loc loc)) ∧
  (!gtagenv vs vs'.
    vs_rel gtagenv vs vs'
    ⇒
    v_rel gtagenv (Vectorv vs) (Vectorv vs')) ∧
  (!gtagenv.
    vs_rel gtagenv [] []) ∧
  (!gtagenv v vs v' vs'.
    v_rel gtagenv v v' ∧
    vs_rel gtagenv vs vs'
    ⇒
    vs_rel gtagenv (v::vs) (v'::vs')) ∧
  (!gtagenv.
    env_rel gtagenv [] []) ∧
  (!gtagenv x v env env' v'.
    env_rel gtagenv env env' ∧
    v_rel gtagenv v v'
    ⇒
    env_rel gtagenv ((x,v)::env) ((x,v')::env'))`;

val v_rel_eqns = Q.store_thm ("v_rel_eqns",
  `(!gtagenv l v.
    v_rel gtagenv (Litv l) v ⇔
      (v = Litv l)) ∧
   (!gtagenv cn vs v.
    v_rel gtagenv (Conv cn vs) v ⇔
      (?vs' otag gtagenv'.
         vs_rel gtagenv vs vs' ∧ (v = Conv otag vs') ∧
         (cn = NONE ∧ otag = NONE ∨
          ?cn' tn tag.
            otag = SOME (tag,tn) ∧
            FLOOKUP gtagenv (cn',tn) = SOME (tag,LENGTH vs) ∧
            cn = SOME (cn',tn)))) ∧
   (!gtagenv l v.
    v_rel gtagenv (Loc l) v ⇔
      (v = Loc l)) ∧
   (!gtagenv cn vs v.
    v_rel gtagenv (Vectorv vs) v ⇔
      (?vs'. vs_rel gtagenv vs vs' ∧ (v = Vectorv vs'))) ∧
   (!gtagenv vs.
    vs_rel gtagenv [] vs ⇔
      (vs = [])) ∧
   (!gtagenv l v vs vs'.
    vs_rel gtagenv (v::vs) vs' ⇔
      ?v' vs''. v_rel gtagenv v v' ∧ vs_rel gtagenv vs vs'' ∧ vs' = v'::vs'') ∧
   (!gtagenv env'.
    env_rel gtagenv [] env' ⇔
      env' = []) ∧
   (!gtagenv x v env env'.
    env_rel gtagenv ((x,v)::env) env' ⇔
      ?v' env''. v_rel gtagenv v v' ∧ env_rel gtagenv env env'' ∧ env' = ((x,v')::env''))`,
  rw [] >>
  rw [Once v_rel_cases] >>
  metis_tac []);

val vs_rel_list_rel = Q.prove (
  `!gtagenv vs vs'. vs_rel gtagenv vs vs' = LIST_REL (v_rel gtagenv) vs vs'`,
   induct_on `vs` >>
   rw [v_rel_eqns] >>
   metis_tac []);

val length_vs_rel = Q.prove (
  `!vs gtagenv vs'.
    vs_rel gtagenv vs vs'
    ⇒
    LENGTH vs = LENGTH vs'`,
  metis_tac[vs_rel_list_rel,LIST_REL_LENGTH])

val v_rel_weakening = Q.prove (
  `(!gtagenv v v_i2.
    v_rel gtagenv v v_i2
    ⇒
      !gtagenv'. gtagenv_weak gtagenv gtagenv'
      ⇒
      v_rel gtagenv' v v_i2) ∧
   (!gtagenv vs vs_i2.
    vs_rel gtagenv vs vs_i2
    ⇒
     !gtagenv'. gtagenv_weak gtagenv gtagenv'
      ⇒
      vs_rel gtagenv' vs vs_i2) ∧
   (!gtagenv env env_i2.
    env_rel gtagenv env env_i2
    ⇒
     !gtagenv'. gtagenv_weak gtagenv gtagenv'
      ⇒
      env_rel gtagenv' env env_i2)`,
  ho_match_mp_tac v_rel_ind >>
  rw [v_rel_eqns] >>
  res_tac
  >- metis_tac [gtagenv_weak_def, FLOOKUP_SUBMAP]
  >- (
      rw [Once v_rel_cases] >>
      fs [cenv_inv_def, gtagenv_wf_def, envC_tagged_def] >>
      imp_res_tac exhaustive_env_weak >>
      MAP_EVERY qexists_tac [`exh'`, `tagenv`] >>
      fs [gtagenv_weak_def, cenv_inv_def, envC_tagged_def, gtagenv_wf_def] >>
      rw []
      >- (res_tac >>
          metis_tac [FLOOKUP_SUBMAP])
      >- (fs [has_exns_def] >>
          metis_tac [FLOOKUP_SUBMAP])
      >- (fs [has_bools_def] >>
          metis_tac [FLOOKUP_SUBMAP])
      >- (fs [has_lists_def] >>
          metis_tac [FLOOKUP_SUBMAP])
      >- metis_tac []
      >- metis_tac [])
  >- (fs [cenv_inv_def, gtagenv_wf_def, envC_tagged_def] >>
      imp_res_tac exhaustive_env_weak >>
      rw [Once v_rel_cases] >>
      MAP_EVERY qexists_tac [`exh'`, `tagenv`] >>
      fs [gtagenv_weak_def, cenv_inv_def, envC_tagged_def, gtagenv_wf_def] >>
      rw []
      >- (res_tac >>
          metis_tac [FLOOKUP_SUBMAP])
      >- (fs [has_exns_def] >>
          metis_tac [FLOOKUP_SUBMAP])
      >- (fs [has_bools_def] >>
          metis_tac [FLOOKUP_SUBMAP])
      >- (fs [has_lists_def] >>
          metis_tac [FLOOKUP_SUBMAP])
      >- metis_tac []
      >- metis_tac []));

val (env_all_rel_rules, env_all_rel_ind, env_all_rel_cases) = Hol_reln `
  (!gtagenv env env_i2.
    cenv_inv env.c env_i2.exh tagenv gtagenv ∧
    env_rel gtagenv env.v env_i2.v
    ⇒
    env_all_rel tagenv (env:modSem$environment) (env_i2:conSem$environment) gtagenv)`;

val env_rel_append = Q.prove (
  `!gtagenv env1 env2 env1' env2'.
    env_rel gtagenv env1 env1' ∧
    env_rel gtagenv env2 env2'
    ⇒
    env_rel gtagenv (env1++env2) (env1'++env2')`,
  induct_on `env1` >>
  rw [v_rel_eqns] >>
  PairCases_on `h` >>
  fs [v_rel_eqns]);

val env_rel_el = Q.prove (
  `!gtagenv env env_i2.
    env_rel gtagenv env env_i2 ⇔
    LENGTH env = LENGTH env_i2 ∧ !n. n < LENGTH env ⇒ (FST (EL n env) = FST (EL n env_i2)) ∧ v_rel gtagenv (SND (EL n env)) (SND (EL n env_i2))`,
  induct_on `env` >>
  rw [v_rel_eqns]
  >- (cases_on `env_i2` >>
      fs []) >>
  PairCases_on `h` >>
  rw [v_rel_eqns] >>
  eq_tac >>
  rw [] >>
  rw []
  >- (cases_on `n` >>
      fs [])
  >- (cases_on `n` >>
      fs [])
  >- (cases_on `env_i2` >>
      fs [] >>
      FIRST_ASSUM (qspecl_then [`0`] mp_tac) >>
      SIMP_TAC (srw_ss()) [] >>
      rw [] >>
      qexists_tac `SND h` >>
      rw [] >>
      FIRST_X_ASSUM (qspecl_then [`SUC n`] mp_tac) >>
      rw []));

val env_rel_lookup = Q.prove (
  `!gtagenv env x v env'.
    ALOOKUP env x = SOME v ∧
    env_rel gtagenv env env'
    ⇒
    ?v'.
      v_rel gtagenv v v' ∧
      ALOOKUP env' x = SOME v'`,
  induct_on `env` >>
  rw [] >>
  PairCases_on `h` >>
  fs [] >>
  cases_on `h0 = x` >>
  fs [] >>
  rw [] >>
  fs [v_rel_eqns]);

val genv_rel_lookup = Q.prove (
  `!gtagenv genv n genv'.
    LIST_REL (OPTION_REL (v_rel gtagenv)) genv genv' ∧
    LENGTH genv > n
    ⇒
    !v.
    EL n genv = SOME v
    ⇒
    ?v'. EL n genv' = SOME v' ∧
    v_rel gtagenv v v'`,
  induct_on `genv` >>
  srw_tac [ARITH_ss] [] >>
  cases_on `n` >>
  srw_tac [ARITH_ss] [] >>
  full_simp_tac (srw_ss()++ARITH_ss) [] >>
  fs [OPTREL_def]);

val (result_rel_rules, result_rel_ind, result_rel_cases) = Hol_reln `
  (∀gtagenv v v'.
    f gtagenv v v'
    ⇒
    result_rel f gtagenv (Rval v) (Rval v')) ∧
  (∀gtagenv v v'.
    v_rel gtagenv v v'
    ⇒
    result_rel f gtagenv (Rerr (Rraise v)) (Rerr (Rraise v'))) ∧
  (!gtagenv a.
    result_rel f gtagenv (Rerr (Rabort a)) (Rerr (Rabort a)))`;

val result_rel_eqns = Q.prove (
  `(!gtagenv v r.
    result_rel f gtagenv (Rval v) r ⇔
      ?v'. f gtagenv v v' ∧ r = Rval v') ∧
   (!gtagenv v r.
    result_rel f gtagenv (Rerr (Rraise v)) r ⇔
      ?v'. v_rel gtagenv v v' ∧ r = Rerr (Rraise v')) ∧
   (!gtagenv v r a.
    result_rel f gtagenv (Rerr (Rabort a)) r ⇔
      r = Rerr (Rabort a))`,
  rw [result_rel_cases] >>
  metis_tac []);

val (sv_rel_rules, sv_rel_ind, sv_rel_cases) = Hol_reln `
  (!genv v v'.
    v_rel genv v v'
    ⇒
    sv_rel genv (Refv v) (Refv v')) ∧
  (!genv w.
    sv_rel genv (W8array w) (W8array w)) ∧
  (!genv vs vs'.
    vs_rel genv vs vs'
    ⇒
    sv_rel genv (Varray vs) (Varray vs'))`;

val sv_rel_weakening = Q.prove (
  `(!gtagenv sv sv_i2 gtagenv'.
    sv_rel gtagenv sv sv_i2 ∧
    gtagenv_weak gtagenv gtagenv'
    ⇒
    sv_rel gtagenv' sv sv_i2)`,
  rw [sv_rel_cases] >>
  metis_tac [v_rel_weakening]);

val (s_rel_rules, s_rel_ind, s_rel_cases) = Hol_reln `
  (!gtagenv s (s':'ffi conSem$state).
    LIST_REL (sv_rel gtagenv) s.refs s'.refs ∧
    LIST_REL (OPTION_REL (v_rel gtagenv)) s.globals s'.globals ∧
    s.clock = s'.clock ∧
    s.ffi = s'.ffi
    ⇒
    s_rel gtagenv s s')`;

val match_result_rel_def = Define
  `(match_result_rel gtagenv (Match env) (Match env_i2) ⇔
     env_rel gtagenv env env_i2) ∧
   (match_result_rel gtagenv No_match No_match = T) ∧
   (match_result_rel gtagenv Match_type_error Match_type_error = T) ∧
   (match_result_rel gtagenv _ _ = F)`;

(* top-level invariant *)

val invariant_def = Define `
  invariant envC tagenv_st gtagenv s s_i2 ⇔
    set (MAP FST (FST envC)) ⊆ s.defined_mods ∧
    (∀x. Short x ∈ FDOM (get_exh tagenv_st) ⇒ TypeId (Short x) ∈ s.defined_types) ∧
    (∀mn x. Long mn x ∈ FDOM (get_exh tagenv_st) ⇒ mn ∈ s.defined_mods) ∧
    cenv_inv envC (get_exh tagenv_st) (get_tagenv ((tagenv_st,FEMPTY):tagenv_state_acc)) gtagenv ∧
    s_rel gtagenv s s_i2 ∧
    next_inv s.defined_types (FST tagenv_st) gtagenv`;

val invariant_with_clock = Q.store_thm("invariant_with_clock",
  `invariant envC tagenv_st gtagenv s s_i2 ⇒
   invariant envC tagenv_st gtagenv (s with clock := k) (s_i2 with clock := k)`,
  rw[invariant_def] >> fs[s_rel_cases] >> metis_tac[])

(* semantic functions respect relation *)

val pmatch = Q.prove (
  `(!envC s p v env r env_i2 s_i2 v_i2 tagenv gtagenv exh.
    r ≠ Match_type_error ∧
    cenv_inv envC exh tagenv gtagenv ∧
    pmatch envC s p v env = r ∧
    LIST_REL (sv_rel gtagenv) s s_i2 ∧
    v_rel gtagenv v v_i2 ∧
    env_rel gtagenv env env_i2
    ⇒
    ?r_i2.
      pmatch exh s_i2 (compile_pat tagenv p) v_i2 env_i2 = r_i2 ∧
      match_result_rel gtagenv r r_i2) ∧
   (!envC s ps vs env r env_i2 s_i2 vs_i2 tagenv gtagenv exh.
    r ≠ Match_type_error ∧
    cenv_inv envC exh tagenv gtagenv ∧
    pmatch_list envC s ps vs env = r ∧
    LIST_REL (sv_rel gtagenv) s s_i2 ∧
    vs_rel gtagenv vs vs_i2 ∧
    env_rel gtagenv env env_i2
    ⇒
    ?r_i2.
      pmatch_list exh s_i2 (MAP (compile_pat tagenv) ps) vs_i2 env_i2 = r_i2 ∧
      match_result_rel gtagenv r r_i2)`,
  ho_match_mp_tac modSemTheory.pmatch_ind >>
  rw [modSemTheory.pmatch_def, conSemTheory.pmatch_def, compile_pat_def, match_result_rel_def] >>
  fs [match_result_rel_def, v_rel_eqns] >>
  rw [conSemTheory.pmatch_def, match_result_rel_def]
  >- (
    every_case_tac >> fs []
      >- (`lookup_tag_env (SOME n) tagenv = SOME (tag, t')`
                   by (qpat_assum`∀x. Y`kall_tac >>
                       fs[cenv_inv_def,envC_tagged_def] >>
                       first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
                       metis_tac [length_vs_rel, SOME_11, same_ctor_and_same_tid, PAIR_EQ]) >>
          rw [conSemTheory.pmatch_def] >>
          `(?tid. t' = TypeId tid) ∨ (?exid. t' = TypeExn exid)`
                     by (Cases_on `t'` >>
                         metis_tac []) >>
          rw [conSemTheory.pmatch_def]
          >- (
              fs[GSYM AND_IMP_INTRO] >>
              first_x_assum(fn th => first_assum(mp_tac o MATCH_MP th)) >>
              rpt(disch_then(fn th => first_assum(mp_tac o MATCH_MP th))) >>
              strip_tac >> (simp_tac(srw_ss()++boolSimps.ETA_ss)[]) >>
              fs[cenv_inv_def,exhaustive_env_correct_def,PULL_EXISTS] >> simp[] >>
              qmatch_assum_rename_tac`FLOOKUP gtagenv (cn,TypeId tid) = _` >>
              first_x_assum(qspecl_then[`tid`,`cn`]mp_tac) >>
              discharge_hyps >- fs[FLOOKUP_DEF] >> rw[] >>
              first_x_assum(qspec_then`cn`mp_tac) >> simp[] >>
              strip_tac >> simp[] >>
              imp_res_tac length_vs_rel >> fs[] >> rw[] >>
              fs[envC_tagged_def] >>
              first_x_assum(fn th => first_x_assum(strip_assume_tac o MATCH_MP th)) >>
              fs[same_ctor_def] >> rw[] >> fs[])
          >- metis_tac [tid_or_exn_11, SOME_11, PAIR_EQ]
          >- (
            imp_res_tac same_ctor_and_same_tid >>
            fs[cenv_inv_def,envC_tagged_def] >>
            res_tac >> rw[] >> fs[] >>
            imp_res_tac length_vs_rel >>
            metis_tac[] ))
      >- (fs [cenv_inv_def, envC_tagged_def] >>
          res_tac >>
          simp_tac(srw_ss()++boolSimps.ETA_ss)[] >>
          rw [] >>
          `(?tid. t' = TypeId tid) ∨ (?exid. t' = TypeExn exid)`
                     by (Cases_on `t'` >>
                         metis_tac []) >>
          `(?tid. r = TypeId tid) ∨ (?exid. r = TypeExn exid)`
                     by (Cases_on `r` >>
                         metis_tac []) >>
          imp_res_tac same_tid_diff_ctor >>
          rw [] >>
          simp [conSemTheory.pmatch_def] >>
          rw[match_result_rel_def] >>
          TRY(fs[same_tid_def]>>NO_TAC)
          >- (
            fs[exhaustive_env_correct_def,PULL_EXISTS] >>
            first_x_assum(qspecl_then[`tid`,`id_to_n n`]mp_tac) >>
            discharge_hyps >- fs[FLOOKUP_DEF] >> strip_tac >> simp[] >>
            first_assum(qspec_then`id_to_n n`mp_tac) >> simp[] >> strip_tac >>
            first_assum(qspec_then`n'`mp_tac) >> simp[] >> strip_tac >>
            imp_res_tac length_vs_rel >> fs[] >>
            rw[match_result_rel_def] >>
            fs[gtagenv_wf_def] >>
            metis_tac[same_tid_refl] )
          >- (
            imp_res_tac length_vs_rel >>
            metis_tac[gtagenv_wf_def] )
          >- metis_tac [tid_or_exn_11, gtagenv_wf_def, length_vs_rel]
          >- ( fs[FLOOKUP_DEF,gtagenv_wf_def] >> metis_tac[] )
          >- metis_tac [tid_or_exn_11, gtagenv_wf_def, length_vs_rel]))
  >- (PairCases_on `tagenv` >>
      fs [conSemTheory.pmatch_def, lookup_tag_env_def] >>
      rw [] >>
      metis_tac [length_vs_rel])
  >- (fs[vs_rel_list_rel] >> imp_res_tac LIST_REL_LENGTH)
  >- (every_case_tac >>
      fs [store_lookup_def] >>
      imp_res_tac LIST_REL_LENGTH >>
      fs [LIST_REL_EL_EQN] >>
      fs [sv_rel_cases] >>
      res_tac >>
      rw [] >>
      fs [] >>
      rw [] >>
      metis_tac [])
  >- (every_case_tac >>
      fs [match_result_rel_def] >>
      rw [] >>
      pop_assum mp_tac >>
      pop_assum mp_tac >>
      res_tac >>
      rw [] >>
      CCONTR_TAC >>
      fs [match_result_rel_def] >>
      metis_tac [match_result_rel_def, match_result_distinct]));

val do_eq = Q.prove (
  `(!v1 v2 r v1_i2 v2_i2 gtagenv.
    gtagenv_wf gtagenv ∧
    do_eq v1 v2 = r ∧
    v_rel gtagenv v1 v1_i2 ∧
    v_rel gtagenv v2 v2_i2
    ⇒
    do_eq v1_i2 v2_i2 = r) ∧
   (!vs1 vs2 r vs1_i2 vs2_i2 gtagenv.
    gtagenv_wf gtagenv ∧
    do_eq_list vs1 vs2 = r ∧
    vs_rel gtagenv vs1 vs1_i2 ∧
    vs_rel gtagenv vs2 vs2_i2
    ⇒
    do_eq_list vs1_i2 vs2_i2 = r)`,
  ho_match_mp_tac modSemTheory.do_eq_ind >>
  rw [conSemTheory.do_eq_def, modSemTheory.do_eq_def, v_rel_eqns] >>
  rw [] >>
  rw [conSemTheory.do_eq_def, modSemTheory.do_eq_def, v_rel_eqns] >>
  imp_res_tac length_vs_rel >>
  fs [env_all_rel_cases,ctor_same_type_def,same_tid_refl] >>
  rw []
  >- metis_tac []
  >- metis_tac []
  >> TRY (
    simp[] >>
    Cases_on`do_eq v1 v2`>>
    CHANGED_TAC(simp[])>>fs[]>>rw[]>>fs[]>>
    CASE_TAC>>rw[]>>fs[]>>res_tac>>fs[])
  >> TRY (
    BasicProvers.CASE_TAC >>
    res_tac >>
    every_case_tac >> fs[same_tid_def] >>
    fs[gtagenv_wf_def,FLOOKUP_DEF] >>
    metis_tac[PAIR_EQ,same_tid_def,tid_or_exn_11] )
  >- metis_tac [same_tid_refl, gtagenv_wf_def, SOME_11, PAIR_EQ, pair_CASES]
  >- metis_tac [cenv_inv_def, gtagenv_wf_def, SOME_11, PAIR_EQ, pair_CASES]
  >> fs [Once v_rel_cases] >>
  rw [conSemTheory.do_eq_def])

val v_to_list = Q.prove (
  `!v1 v2 vs1.
    gtagenv_wf gtagenv ∧
    v_rel gtagenv v1 v2 ∧
    v_to_list v1 = SOME vs1
    ⇒
    ?vs2.
      v_to_list v2 = SOME vs2 ∧
      vs_rel gtagenv vs1 vs2`,
  ho_match_mp_tac modSemTheory.v_to_list_ind >>
  rw [modSemTheory.v_to_list_def] >>
  every_case_tac >>
  fs [v_rel_eqns, conSemTheory.v_to_list_def] >>
  rw [] >>
  every_case_tac >>
  fs [v_rel_eqns, conSemTheory.v_to_list_def] >>
  rw [] >>
  res_tac >>
  fs [gtagenv_wf_def, has_lists_def] >>
  res_tac >>
  fs [] >>
  metis_tac [NOT_SOME_NONE, SOME_11]);

val char_list_to_v = prove(
  ``gtagenv_wf gtagenv ⇒
    ∀ls. v_rel gtagenv (char_list_to_v ls) (char_list_to_v ls)``,
  strip_tac >>
  Induct >> simp[modSemTheory.char_list_to_v_def,conSemTheory.char_list_to_v_def,v_rel_eqns] >>
  fs[gtagenv_wf_def,has_lists_def])

val v_to_char_list = Q.prove (
  `!v1 v2 vs1.
    gtagenv_wf gtagenv ∧
    v_rel gtagenv v1 v2 ∧
    v_to_char_list v1 = SOME vs1
    ⇒
      v_to_char_list v2 = SOME vs1`,
  ho_match_mp_tac modSemTheory.v_to_char_list_ind >>
  rw [modSemTheory.v_to_char_list_def] >>
  every_case_tac >>
  fs [v_rel_eqns, conSemTheory.v_to_char_list_def] >>
  rw [] >>
  every_case_tac >>
  fs [v_rel_eqns, conSemTheory.v_to_char_list_def] >>
  rw [] >>
  res_tac >>
  fs [gtagenv_wf_def, has_lists_def])

val Boolv = Q.prove(
  `gtagenv_wf gtagenv ⇒
   v_rel gtagenv (Boolv b) (Boolv b) ∧
   (∀v. v_rel gtagenv (Boolv b) v ⇔ (v = Boolv b)) ∧
   (∀v. v_rel gtagenv v (Boolv b) ⇔ (v = Boolv b))`,
  rw[Once v_rel_cases,modSemTheory.Boolv_def,conSemTheory.Boolv_def,
     vs_rel_list_rel,gtagenv_wf_def,has_bools_def] >>
  rw[Once v_rel_cases] >>
  rw[Once v_rel_cases] >>
  metis_tac[same_tid_refl])

val tac =
  fs [modSemTheory.do_app_def] >>
  every_case_tac >>
  fs [vs_rel_list_rel] >>
  rw [conSemTheory.do_app_def] >>
  fs [LET_THM,store_lookup_def, store_alloc_def, store_assign_def, v_rel_eqns, result_rel_cases,
      modSemTheory.prim_exn_def, conSemTheory.prim_exn_def, conSemTheory.exn_tag_def] >>
  imp_res_tac LIST_REL_LENGTH >>
  rw [] >>
  fs [] >>
  fs [] >>
  fs[LIST_REL_EL_EQN,sv_rel_cases] >>
  res_tac >>
  fs [store_v_same_type_def] >>
  rw [EL_LUPDATE, v_rel_eqns] >>
  rw [] >>
  fs [v_rel_eqns] >>
  rw [v_rel_eqns] >>
  fs [Boolv] >>
  TRY (fs [gtagenv_wf_def, has_exns_def] >> NO_TAC);

val do_app = Q.prove (
  `!gtagenv s1 s2 op vs r s1_i2 vs_i2.
    do_app s1 op vs = SOME (s2, r) ∧
    LIST_REL (sv_rel gtagenv) (FST s1) (FST s1_i2) ∧
    SND s1 = SND s1_i2 ∧
    vs_rel gtagenv vs vs_i2 ∧
    gtagenv_wf gtagenv
    ⇒
     ∃r_i2 s2_i2.
       LIST_REL (sv_rel gtagenv) (FST s2) (FST s2_i2) ∧
       SND s2 = SND s2_i2 ∧
       result_rel v_rel gtagenv r r_i2 ∧
       do_app s1_i2 (Op op) vs_i2 = SOME (s2_i2, r_i2)`,
  rpt gen_tac >>
  Cases_on `s1` >>
  Cases_on `s1_i2` >>
  cases_on `op` >>
  rw []
  >- tac
  >- tac
  >- (fs [modSemTheory.do_app_def] >>
      cases_on `vs` >>
      fs [] >>
      cases_on `t` >>
      fs [] >>
      cases_on `t'` >>
      fs [vs_rel_list_rel] >>
      rw []
      >- (every_case_tac >>
          imp_res_tac do_eq >>
          rw [conSemTheory.do_app_def, result_rel_cases, v_rel_eqns, modSemTheory.prim_exn_def, conSemTheory.prim_exn_def, conSemTheory.exn_tag_def] >>
          rw [] >> fs[Boolv] >>
          fs [gtagenv_wf_def, has_exns_def])
      >- (every_case_tac >>
          fs []))
  >- tac
  >- tac
  >- tac
  >- tac
  >- tac
  >- (tac >>
      pop_assum mp_tac >>
      rw [])
  >- tac
  >- (tac >>
      pop_assum mp_tac >>
      rw [EL_LUPDATE] >>
      fs [LENGTH_LUPDATE] >>
      pop_assum mp_tac >>
      pop_assum mp_tac >>
      rw [])
  >- tac
  >- tac
  >- tac
  >- (
    tac >>
    simp[char_list_to_v] )
  >- (
    fs[modSemTheory.do_app_def]>>
    Cases_on`vs`>>fs[]>>
    Cases_on`t`>>fs[]>>
    TRY (cases_on `t'`) >>
    fs [vs_rel_list_rel] >> rw [] >- (
      every_case_tac >>
      imp_res_tac v_to_char_list >>
      fs[] >> rw[conSemTheory.do_app_def,result_rel_cases,v_rel_eqns]) >>
    every_case_tac >> fs[])
  >- tac
  >- (fs [modSemTheory.do_app_def] >>
      cases_on `vs` >>
      fs [] >>
      cases_on `t` >>
      fs [] >>
      TRY (cases_on `t'`) >>
      fs [vs_rel_list_rel] >>
      rw []
      >- (every_case_tac >>
          imp_res_tac v_to_list >>
          rw [conSemTheory.do_app_def, result_rel_cases, v_rel_eqns, modSemTheory.prim_exn_def, conSemTheory.prim_exn_def, conSemTheory.exn_tag_def] >>
          rw [])
      >- (every_case_tac >>
          fs []))
  >- (tac >>
      fs [vs_rel_list_rel] >>
      imp_res_tac LIST_REL_LENGTH >>
      fs [] >>
      rw [v_rel_eqns] >>
      rpt (pop_assum mp_tac) >>
      rw []
      >- fs [gtagenv_wf_def, has_exns_def] >>
      fs [LIST_REL_EL_EQN] >>
      FIRST_X_ASSUM match_mp_tac >>
      decide_tac)
  >- (tac >>
      fs [vs_rel_list_rel] >>
      imp_res_tac LIST_REL_LENGTH >>
      fs [])
  >- (tac >>
      fs [vs_rel_list_rel, LIST_REL_EL_EQN, LENGTH_REPLICATE, EL_REPLICATE] >>
      rw [v_rel_eqns, vs_rel_list_rel, LIST_REL_EL_EQN])
  >- (tac >>
      fs [vs_rel_list_rel] >>
      imp_res_tac LIST_REL_LENGTH >>
      fs [] >>
      rw [v_rel_eqns] >>
      rpt (pop_assum mp_tac) >>
      rw []
      >- fs [gtagenv_wf_def, has_exns_def] >>
      fs [LIST_REL_EL_EQN] >>
      FIRST_X_ASSUM match_mp_tac >>
      decide_tac)
  >- (tac >>
      fs [vs_rel_list_rel, LIST_REL_EL_EQN, LENGTH_REPLICATE, EL_REPLICATE] >>
      rw [v_rel_eqns, vs_rel_list_rel, LIST_REL_EL_EQN])
  >- (tac >>
      fs [vs_rel_list_rel] >>
      imp_res_tac LIST_REL_LENGTH >>
      fs [] >>
      rw [v_rel_eqns] >>
      rpt (pop_assum mp_tac) >>
      rw []
      >- fs [gtagenv_wf_def, has_exns_def] >>
      fs [LIST_REL_EL_EQN] >>
      rw [EL_LUPDATE] >>
      full_case_tac >>
      metis_tac [])
  >- tac);

val do_opapp = Q.prove (
  `!gtagenv vs vs_i2 env e genv env' tagenv env_i2.
    do_opapp vs = SOME (env', e) ∧
    env_all_rel tagenv env env_i2 gtagenv ∧
    vs_rel gtagenv vs vs_i2
    ⇒
     ∃tagenv env_i2'.
       env_all_rel tagenv env' (env_i2 with v := env_i2') gtagenv ∧
       do_opapp vs_i2 = SOME (env_i2', compile_exp tagenv e)`,
  rw [modSemTheory.do_opapp_def] >>
  every_case_tac >>
  fs [conSemTheory.do_opapp_def, vs_rel_list_rel] >>
  rw []
  >- (qpat_assum `v_rel a0 (Closure b0 c0 d0) e0` (mp_tac o SIMP_RULE (srw_ss()) [Once v_rel_cases]) >>
      rw [] >>
      rw [] >>
      qexists_tac `tagenv'` >>
      rw [] >>
      fs [env_all_rel_cases] >>
      rw [v_rel_eqns, get_tagenv_def] >>
      fs [cenv_inv_def])
  >- (qpat_assum `v_rel a0 (Recclosure b0 c0 d0) e0` (mp_tac o SIMP_RULE (srw_ss()) [Once v_rel_cases]) >>
      rw [] >>
      rw [] >>
      every_case_tac >>
      fs []
      >- (fs [find_recfun_ALOOKUP] >>
          induct_on `l` >>
          rw [] >>
          PairCases_on `h'` >>
          fs [compile_exp_def] >>
          every_case_tac >>
          fs [])
      >- (qexists_tac `tagenv'` >>
          rw [] >>
          fs [env_all_rel_cases] >>
          rw [v_rel_eqns, conPropsTheory.build_rec_env_merge, modPropsTheory.build_rec_env_merge] >>
          fs [compile_funs_map]
          >- fs [cenv_inv_def]
          >- (match_mp_tac env_rel_append >>
              rw [compile_funs_map, MAP_MAP_o, combinTheory.o_DEF, LAMBDA_PROD, env_rel_el, EL_MAP] >>
              `?f x e. EL n l = (f,x,e)` by metis_tac [pair_CASES] >>
              rw [] >>
              rw [Once v_rel_cases] >>
              metis_tac [compile_funs_map])
          >- (fs [find_recfun_ALOOKUP] >>
              induct_on `l` >>
              rw [] >>
              PairCases_on `h'` >>
              fs [compile_exp_def] >>
              every_case_tac >>
              fs [])
          >- (CCONTR_TAC >> fs[compile_funs_map] >>
              fs[MAP_MAP_o,combinTheory.o_DEF,UNCURRY,ETA_AX,FST_triple])
          >- (fs [find_recfun_ALOOKUP] >>
              induct_on `l` >>
              rw [] >>
              PairCases_on `h'` >>
              fs [compile_exp_def] >>
              every_case_tac >>
              fs [get_tagenv_def] >>
              rw []))));

val pat_bindings = Q.prove (
  `!tagenv p x. pat_bindings (compile_pat tagenv p) x = pat_bindings p x`,
  ho_match_mp_tac compile_pat_ind >>
  rw [conSemTheory.pat_bindings_def, astTheory.pat_bindings_def, compile_pat_def] >>
  induct_on `ps` >>
  rw [] >>
  fs [conSemTheory.pat_bindings_def, astTheory.pat_bindings_def, compile_pat_def] >>
  metis_tac [APPEND_11, evalPropsTheory.pat_bindings_accum, conPropsTheory.pat_bindings_accum]);

val pmatch_exh_weak = Q.prove (
  `(!(exh:exh_ctors_env) s p v env res exh'.
    pmatch exh s p v env = res ∧
    res ≠ Match_type_error ∧
    exh_weak exh exh'
    ⇒
    pmatch exh' s p v env = res) ∧
   (!(exh:exh_ctors_env) s ps vs env res exh'.
    pmatch_list exh s ps vs env = res ∧
    res ≠ Match_type_error ∧
    exh_weak exh exh'
    ⇒
    pmatch_list exh' s ps vs env = res)`,
  ho_match_mp_tac conSemTheory.pmatch_ind >>
  rw [conSemTheory.pmatch_def, LET_THM] >>
  every_case_tac >>
  rw [] >>
  TRY (
    fs [exh_weak_def] >> res_tac >> fs[] >> rw[] >> res_tac >> fs[] >> rw[] >> DECIDE_TAC) >>
  metis_tac [exh_weak_def,NOT_SOME_NONE,match_result_distinct, match_result_11]);

val s = mk_var("s",
  ``conSem$evaluate`` |> type_of |> strip_fun |> #1 |> el 2
  |> type_subst[alpha |-> ``:'ffi``])

val evaluate_exh_weak = Q.prove (
  `(∀env ^s es res.
     evaluate env s es = res ⇒
     !exh'.
       SND res ≠ Rerr (Rabort Rtype_error) ∧
       exh_weak env.exh exh' ⇒
       evaluate (env with exh := exh') s es = res) ∧
   (∀env ^s v pes err_v res.
     evaluate_match env s v pes err_v = res ⇒
     !exh'.
       SND res ≠ Rerr (Rabort Rtype_error) ∧
       exh_weak env.exh exh' ⇒
       evaluate_match (env with exh := exh') s v pes err_v = res)`,
  ho_match_mp_tac conSemTheory.evaluate_ind >>
  rw [conSemTheory.evaluate_def] >>
  every_case_tac >> fs[] >>
  res_tac >> fs[] >> rfs[] >> rw[] >>
  metis_tac [pmatch_exh_weak, match_result_distinct, match_result_11]);

val evaluate_dec_exh_weak = prove(
  ``∀env ^s d res.
      evaluate_dec env s d = res ⇒
      ∀exh'. exh_weak env.exh exh' ∧ SND res ≠ Rerr (Rabort Rtype_error)
        ⇒ evaluate_dec (env with exh := exh') s d = res``,
  Cases_on`d`>>rw[conSemTheory.evaluate_dec_def] >>
  pop_assum mp_tac >> BasicProvers.CASE_TAC >> fs[] >>
  imp_res_tac evaluate_exh_weak >> fs[] >>
  res_tac >> every_case_tac >> fs[]);

val evaluate_decs_exh_weak = prove(
 ``∀env ^s ds res.
     evaluate_decs env s ds = res
     ⇒
     ∀exh'. exh_weak env.exh exh' ∧ SND (SND res) ≠ SOME (Rabort Rtype_error) ⇒
       evaluate_decs (env with exh := exh') s ds = res``,
  Induct_on`ds`>>rw[conSemTheory.evaluate_decs_def] >>
  pop_assum mp_tac >>
  BasicProvers.CASE_TAC >> fs[] >>
  imp_res_tac evaluate_dec_exh_weak >> fs[] >>
  every_case_tac >> fs[] >> strip_tac >>
  rator_x_assum`evaluate_decs`mp_tac >>
  qmatch_assum_abbrev_tac`evaluate_decs env1 s1 _ = _` >>
  strip_tac >>
  first_x_assum(qspecl_then[`env1`,`s1`,`exh'`]mp_tac) >>
  simp[Abbr`env1`]);

val evaluate_prompt_exh_weak = Q.prove (
  `!env s p s' genv' res exh1.
   evaluate_prompt env s p = (s',genv',res) ∧
   exh_weak env.exh exh1 ∧ res ≠ SOME (Rabort Rtype_error)
   ⇒
   evaluate_prompt (env with exh := exh1)  s p = (s',genv',res)`,
  Cases_on`p`>>rw[conSemTheory.evaluate_prompt_def] >>
  last_x_assum mp_tac >> BasicProvers.CASE_TAC >> fs[] >>
  first_x_assum(strip_assume_tac o MATCH_MP evaluate_decs_exh_weak) >>
  first_x_assum(qspec_then`exh1`mp_tac) >>
  rw[] >> every_case_tac >> fs[] >>
  rpt var_eq_tac >> fs[]);

(* compiler correctness *)

val s = mk_var("s",
  ``modSem$evaluate`` |> type_of |> strip_fun |> #1 |> el 2
  |> type_subst[alpha |-> ``:'ffi``])

val compile_exp_correct = Q.prove (
  `(∀env ^s es res.
     evaluate env s es = res ⇒
     (SND res ≠ Rerr (Rabort Rtype_error)) ⇒
     !tagenv s' r env_i2 s_i2 es_i2 gtagenv.
       (res = (s',r)) ∧
       env_all_rel tagenv env env_i2 gtagenv ∧
       s_rel gtagenv s s_i2 ∧
       (es_i2 = compile_exps tagenv es)
       ⇒
       ?s'_i2 r_i2.
         result_rel vs_rel gtagenv r r_i2 ∧
         s_rel gtagenv s' s'_i2 ∧
         evaluate env_i2 s_i2 es_i2 = (s'_i2, r_i2)) ∧
   (∀env ^s v pes err_v res.
     evaluate_match env s v pes err_v = res ⇒
     (SND res ≠ Rerr (Rabort Rtype_error)) ⇒
     !tagenv s' r env_i2 s_i2 v_i2 pes_i2 err_v_i2 gtagenv.
       (res = (s',r)) ∧
       env_all_rel tagenv env env_i2 gtagenv ∧
       s_rel gtagenv s s_i2 ∧
       v_rel gtagenv v v_i2 ∧
       pes_i2 = compile_pes tagenv pes ∧
       v_rel gtagenv err_v err_v_i2
       ⇒
       ?s'_i2 r_i2.
         result_rel vs_rel gtagenv r r_i2 ∧
         s_rel gtagenv s' s'_i2 ∧
         evaluate_match env_i2 s_i2 v_i2 pes_i2 err_v_i2 = (s'_i2, r_i2))`,
  ho_match_mp_tac modSemTheory.evaluate_ind >>
  rw [conSemTheory.evaluate_def,modSemTheory.evaluate_def,compile_exp_def] >>
  fs [result_rel_eqns, v_rel_eqns] >>
  TRY(first_assum(split_pair_case_tac o lhs o concl) >> fs[])
  >- (
    every_case_tac >> fs[] >> rpt var_eq_tac >>
    imp_res_tac modPropsTheory.evaluate_sing >>
    rpt var_eq_tac >> fs[] >>
    fs[result_rel_eqns,PULL_EXISTS] >>
    imp_res_tac conPropsTheory.evaluate_sing >>
    rpt var_eq_tac >> fs[] >>
    res_tac >> fs[] >>
    rpt var_eq_tac >>
    fs[vs_rel_list_rel,PULL_EXISTS] >>
    res_tac >> fs[] >>
    rpt var_eq_tac >> simp[] >>
    fs[result_rel_cases] )
  >- (
    every_case_tac >> fs[] >> rpt var_eq_tac >>
    imp_res_tac modPropsTheory.evaluate_sing >>
    rpt var_eq_tac >> fs[] >>
    fs[result_rel_eqns,PULL_EXISTS] >>
    imp_res_tac conPropsTheory.evaluate_sing >>
    rpt var_eq_tac >> fs[] >>
    res_tac >> fs[] >>
    rpt var_eq_tac >>
    fs[vs_rel_list_rel,PULL_EXISTS] >>
    fs[result_rel_cases] )
  >- (
    every_case_tac >> fs[] >> rpt var_eq_tac >>
    imp_res_tac modPropsTheory.evaluate_sing >>
    rpt var_eq_tac >> fs[] >>
    fs[result_rel_eqns,PULL_EXISTS] >>
    imp_res_tac conPropsTheory.evaluate_sing >>
    rpt var_eq_tac >> fs[] >>
    res_tac >> fs[] >>
    rpt var_eq_tac >>
    fs[vs_rel_list_rel,PULL_EXISTS])
  >- (* Constructor application *)
     (
    every_case_tac >> fs[] >> rpt var_eq_tac >>
    fs[result_rel_eqns,vs_rel_list_rel,v_rel_eqns,PULL_EXISTS] >>
    res_tac >> fs[] >> rpt var_eq_tac >>
    fs[modSemTheory.build_conv_def] >>
    every_case_tac >> fs[] >> rpt var_eq_tac >>
    fs[v_rel_eqns,vs_rel_list_rel,compile_exps_map,MAP_REVERSE] >>
    res_tac >> fs[] >>
    rpt var_eq_tac >> fs[EVERY2_REVERSE] >>
    fs[env_all_rel_cases,cenv_inv_def,envC_tagged_def,gtagenv_wf_def,do_con_check_def] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(th))) >>
    strip_tac >> fs[LIST_REL_EL_EQN] >>
    imp_res_tac evaluate_length >> fs[] >>
    fs[result_rel_cases] )
  >- (* Local variable lookup *)
     (fs [env_all_rel_cases] >>
      rw [] >>
      every_case_tac >> fs[result_rel_eqns] >>
      imp_res_tac env_rel_lookup >> fs[v_rel_eqns] >> rw[])
  >- (* Global variable lookup *)
     (fs [s_rel_cases] >>
      rw [] >> fs [] >>
      `LENGTH s.globals > n` by decide_tac >>
      `LENGTH s_i2.globals = LENGTH s.globals` by metis_tac [LIST_REL_LENGTH] >>
      imp_res_tac genv_rel_lookup >>
      rfs[IS_SOME_EXISTS] >>
      metis_tac[SOME_11])
  >- (rw [Once v_rel_cases] >>
      fs [env_all_rel_cases] >>
      metis_tac [])
  >- (* Function application *)
     (
    fs[compile_exps_map,MAP_REVERSE] >>
    Cases_on`op=Opapp`>>fs[] >- (
      every_case_tac >> fs[] >> rpt var_eq_tac >> fs[] >> rfs[] >>
      first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
      disch_then(fn th => first_assum(mp_tac o MATCH_MP(th))) >> strip_tac >> fs[] >>
      rpt var_eq_tac >> fs[result_rel_eqns] >>
      fs[vs_rel_list_rel] >> imp_res_tac EVERY2_REVERSE >>
      imp_res_tac do_opapp >> fs[vs_rel_list_rel] >>
      res_tac >> fs[] >>
      rpt var_eq_tac >> fs[result_rel_cases] >>
      fs[s_rel_cases] >>
      fs[modSemTheory.dec_clock_def,conSemTheory.dec_clock_def] ) >>
    every_case_tac >> fs[] >> rpt var_eq_tac >> fs[] >> rfs[] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP(th))) >> strip_tac >> fs[] >>
    rpt var_eq_tac >> fs[result_rel_eqns] >>
    fs[vs_rel_list_rel] >> imp_res_tac EVERY2_REVERSE >>
    `gtagenv_wf gtagenv` by fs [env_all_rel_cases, cenv_inv_def] >>
    imp_res_tac do_app >> rfs[vs_rel_list_rel] >>
    fsrw_tac[QUANT_INST_ss[pair_default_qp]][] >>
    res_tac >> fs[s_rel_cases] >>
    res_tac >> rfs[s_rel_cases] >>
    fs[result_rel_cases,vs_rel_list_rel] )
  >- (* If *)
   (
    rfs [modSemTheory.do_if_def] >>
    simp[conSemTheory.pat_bindings_def] >>
    qmatch_assum_rename_tac`_ = (_,rr)` >>
    reverse(Cases_on`rr`)>>fs[] >- (
      rpt var_eq_tac >> fs[] >>
      res_tac >> fs[result_rel_cases] ) >>
    imp_res_tac modPropsTheory.evaluate_sing >> fs[] >>
    every_case_tac >> fs[] >> rfs[] >>
    rpt var_eq_tac >> fs[result_rel_eqns,PULL_EXISTS,vs_rel_list_rel] >>
    fs[v_rel_eqns,modSemTheory.Boolv_def,PULL_EXISTS] >>
    first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_x_assum(mp_tac o MATCH_MP th)) >> strip_tac >>
    last_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
    disch_then(fn th => first_x_assum(mp_tac o MATCH_MP th)) >> strip_tac >>
    fs[] >> rpt var_eq_tac >>
    fs[env_all_rel_cases,cenv_inv_def,exhaustive_env_correct_def] >>
    fs[gtagenv_wf_def,has_bools_def] >> rpt var_eq_tac >> fs[] >>
    fs[conSemTheory.pmatch_def] >>
    fs[PULL_EXISTS,FLOOKUP_DEF] >>
    every_case_tac >> fs[LET_THM] >>
    rpt var_eq_tac >> fs[EVAL``true_tag = false_tag``] >> rfs[] >>
    every_case_tac >> fs[]>> rw[] >>
    metis_tac[NOT_SOME_NONE,SOME_11])
  >- (* Match *)
   (
     every_case_tac >> fs[] >> rfs[PULL_EXISTS] >>
     imp_res_tac conPropsTheory.evaluate_sing >> fs[] >>
     imp_res_tac modPropsTheory.evaluate_sing >> fs[] >>
     res_tac >> fs[] >> rpt var_eq_tac >> fs[result_rel_eqns,vs_rel_list_rel,PULL_EXISTS] >> rfs[] >>
     TRY (
       first_x_assum(match_mp_tac o MP_CANON) >> fs[] >>
       fs [env_all_rel_cases] >>
       fs [cenv_inv_def, envC_tagged_def, gtagenv_wf_def, has_exns_def] ) >>
     res_tac >> fs[result_rel_cases,PULL_EXISTS] >> rpt var_eq_tac >> fs[] >>
     rw[])
  >- (* Let *)
   (
     every_case_tac >> fs[] >> rfs[PULL_EXISTS] >>
     imp_res_tac conPropsTheory.evaluate_sing >> fs[] >>
     imp_res_tac modPropsTheory.evaluate_sing >> fs[] >>
     res_tac >> fs[] >> rpt var_eq_tac >> fs[result_rel_eqns,vs_rel_list_rel,PULL_EXISTS] >> rfs[] >>
     res_tac >> fs[result_rel_cases,PULL_EXISTS] >> rpt var_eq_tac >> fs[] >>
     rw[] >>
     first_x_assum(match_mp_tac o MP_CANON) >>
     fs[env_all_rel_cases,env_rel_el,libTheory.opt_bind_def] >>
     every_case_tac >> fs[] >>
     Cases >> simp[])
  >- (* Letrec *)
  (
     simp[compile_funs_map,MAP_MAP_o,o_DEF,UNCURRY,ETA_AX] >>
     first_x_assum(match_mp_tac o MP_CANON) >>
     fs[env_all_rel_cases] >>
     rw [modPropsTheory.build_rec_env_merge, conPropsTheory.build_rec_env_merge] >>
     match_mp_tac env_rel_append >>
     rw [] >>
     rw [ MAP_MAP_o, combinTheory.o_DEF, LAMBDA_PROD, env_rel_el, EL_MAP,UNCURRY] >>
     rw[Once v_rel_cases] >>
     simp[compile_funs_map] >>
     metis_tac[] )
  >- (
   simp[pat_bindings] >>
   qspecl_then[`env.c`,`s.refs`,`p`,`v`,`env.v`]mp_tac (CONJUNCT1 pmatch) >> simp[] >>
   disch_then(qspecl_then[`env_i2.v`,`s_i2.refs`,`v_i2`,`tagenv`,`gtagenv`,`env_i2.exh`]mp_tac) >>
   discharge_hyps >- (
     fs[env_all_rel_cases,s_rel_cases] >>
     strip_tac >> fs[] ) >> strip_tac >>
   every_case_tac >> fs[] >> rfs[match_result_rel_def] >>
   first_x_assum match_mp_tac >>
   fs[env_all_rel_cases]));

val alloc_tag_accumulates = Q.prove(
  `∀tn cn arity ta.
    ∃acc. SND (alloc_tag tn cn arity ta) = acc ⊌ SND ta ∧
         FDOM acc = {cn} ∧
         OPTION_MAP SND (FLOOKUP acc cn) = lookup_tag_env (SOME (Short cn)) (get_tagenv (alloc_tag tn cn arity ta))`,
  rpt gen_tac >>
  PairCases_on`ta` >>
  rw[alloc_tag_def] >>
  every_case_tac >> simp[] >>
  simp[Once FUPDATE_EQ_FUNION] >>
  (fn g => (g |> snd |> strip_exists |> snd |> dest_conj |> fst |> lhs |> REFL |> concl |> match_exists_tac) g) >>
  simp[lookup_tag_env_def,FLOOKUP_UPDATE,get_tagenv_def,insert_tag_env_def,lookup_tag_flat_def])

val lookup_tag_env_insert = Q.prove (
  `(!cn tag tagenv. lookup_tag_env (SOME (Short cn)) (insert_tag_env cn tag tagenv) = SOME (SND tag)) ∧
   (!cn cn' tag tagenv.
     cn' ≠ Short cn
     ⇒
     lookup_tag_env (SOME cn') (insert_tag_env cn tag tagenv) = lookup_tag_env (SOME cn') tagenv)`,
  rw [] >>
  PairCases_on `tagenv` >>
  rw [lookup_tag_env_def, insert_tag_env_def, lookup_tag_flat_def, FLOOKUP_UPDATE] >>
  every_case_tac >>
  fs []);

val lookup_tag_env_Short_alloc_tag_notin = Q.prove(
  `b ≠ x ⇒
   lookup_tag_env (SOME (Short x)) (get_tagenv (alloc_tag a b c d)) =
   lookup_tag_env (SOME (Short x)) (get_tagenv d)`,
   PairCases_on`d`>>simp[alloc_tag_def] >>
   every_case_tac >> simp[get_tagenv_def,lookup_tag_env_insert])

val lookup_tag_env_Short_alloc_tags0_notin = Q.prove(
  `x ∉ set (MAP FST f) ⇒
   lookup_tag_env (SOME (Short x)) (get_tagenv
     (FOLDL (λa (b,c). alloc_tag e b (LENGTH c) a) d f)) =
   lookup_tag_env (SOME (Short x)) (get_tagenv (d:tagenv_state_acc))`,
  qid_spec_tac`d` >> Induct_on`f` >> simp[] >>
  Cases >> simp[lookup_tag_env_Short_alloc_tag_notin])

val lookup_tag_env_Short_alloc_tags_notin = Q.prove(
  `x ∉ set (MAP FST (FLAT (MAP (SND o SND) c))) ⇒
   lookup_tag_env (SOME (Short x)) (get_tagenv (alloc_tags a (b:tagenv_state_acc) c)) =
   lookup_tag_env (SOME (Short x)) (get_tagenv b)`,
  map_every qid_spec_tac[`a`,`b`,`c`] >>
  Induct >> simp[alloc_tags_def] >>
  qx_gen_tac`p`>>PairCases_on`p` >>
  simp[alloc_tags_def,lookup_tag_env_Short_alloc_tags0_notin])

val FOLDL_alloc_tag_accumulates = Q.prove(
  `∀ls (st:tagenv_state_acc).
    ∃acc. SND (FOLDL (λst' (cn,ts). alloc_tag (TypeId (mk_id mn tn)) cn (LENGTH ts) st') st ls) =
         acc ⊌ SND st ∧
         FDOM acc = set (MAP FST ls) ∧
         (∀cn. MEM cn (MAP FST ls) ⇒
           OPTION_MAP SND (FLOOKUP acc cn) =
           lookup_tag_env (SOME (Short cn))
             (get_tagenv (FOLDL (λst' (cn,ts). alloc_tag (TypeId (mk_id mn tn)) cn (LENGTH ts) st') st ls)))`,
  ho_match_mp_tac SNOC_INDUCT >>
  simp[FDOM_EQ_EMPTY] >> rw[] >>
  simp[FOLDL_SNOC,UNCURRY] >>
  specl_args_of_then``alloc_tag``alloc_tag_accumulates strip_assume_tac >>
  simp[] >>
  first_x_assum(qspec_then`st`strip_assume_tac) >> rw[] >>
  qexists_tac`acc ⊌ acc'` >>
  simp[MAP_SNOC,LIST_TO_SET_SNOC,FUNION_ASSOC,GSYM INSERT_SING_UNION] >>
  simp[FLOOKUP_FUNION] >>
  rw[] >> every_case_tac >> fs[] >>
  TRY(rfs[FLOOKUP_DEF]>>NO_TAC) >>
  TRY(
    `FST x ≠ cn` by (rfs[FLOOKUP_DEF]) >>
    simp[lookup_tag_env_Short_alloc_tag_notin] >>
    NO_TAC) >>
  rfs[FLOOKUP_DEF] >> fs[])

val alloc_tags_accumulates = Q.prove(
  `∀ls mn ta.
    ∃acc. SND (alloc_tags (mn:modN option) (ta:tagenv_state_acc) (ls:type_def)) = acc ⊌ SND ta ∧
          FDOM acc = set (MAP FST (build_tdefs mn ls)) ∧
          (∀cn. MEM cn (MAP FST (build_tdefs mn ls)) ⇒
           OPTION_MAP SND (FLOOKUP acc cn) =
           lookup_tag_env (SOME (Short cn))
             (get_tagenv (alloc_tags mn ta ls)))`,
  Induct >> rw[alloc_tags_def] >- (
    simp[build_tdefs_def,FDOM_EQ_EMPTY] ) >>
  PairCases_on`h`>>simp[alloc_tags_def]>>
  simp[build_tdefs_cons] >>
  qho_match_abbrev_tac`∃acc. SND (alloc_tags mn ta' ls) = acc ⊌ SND ta ∧ X acc` >>
  qunabbrev_tac`X` >>
  Q.ISPECL_THEN[`h1`,`h2`,`ta`]strip_assume_tac (Q.GEN`tn`FOLDL_alloc_tag_accumulates) >>
  first_x_assum(qspecl_then[`mn`,`ta'`]mp_tac) >> rw[] >> rw[] >>
  rfs[] >>
  qexists_tac`acc' ⊌ acc` >>
  simp[FUNION_ASSOC,MAP_REVERSE,MAP_MAP_o,combinTheory.o_DEF,UNCURRY,ETA_AX] >>
  simp[FLOOKUP_FUNION] >>
  rw[] >> every_case_tac >> fs[] >>
  TRY(rfs[FLOOKUP_DEF]>>NO_TAC) >>
  TRY(
    match_mp_tac EQ_SYM >>
    match_mp_tac lookup_tag_env_Short_alloc_tags_notin >>
    rfs[FLOOKUP_DEF] >>
    fs[MAP_FST_build_tdefs] ) >>
  TRY (
    rfs[FLOOKUP_DEF] >> rw[] ) >>
  metis_tac[optionTheory.OPTION_MAP_DEF])

val tagacc_accumulates = Q.prove (
  `!(tagenv_st:tagenv_state_acc) ds tagenv_st' ds_i2'.
    compile_decs tagenv_st ds = (tagenv_st',ds_i2') ⇒
    ?acc'. SND tagenv_st' = FUNION acc' (SND tagenv_st)`,
  induct_on `ds` >>
  rw [compile_decs_def]
  >- metis_tac [FUNION_FEMPTY_1] >>
  every_case_tac >>
  rw [] >>
  fs [LET_THM] >>
  first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >> rw[] >>
  res_tac >> rw[]
  >> metis_tac[alloc_tag_accumulates,alloc_tags_accumulates,FUNION_ASSOC])

val alloc_tag_exh_weak = store_thm("alloc_tag_exh_weak",
  ``exh_weak (get_exh (FST st)) (get_exh (FST (alloc_tag a b c st)))``,
  `∃next menv env exh acc. st = ((next,(menv,env),exh),acc)` by metis_tac[PAIR] >>
  simp[alloc_tag_def]>>
  every_case_tac >> simp[UNCURRY,get_exh_def,exh_weak_def] >> rw[] >>
  simp[FLOOKUP_UPDATE] >> rw[] >>
  rw[sptreeTheory.lookup_insert] >> fs[] >> rw[] >> fs[])

val alloc_tags_exh_weak = store_thm("alloc_tags_exh_weak",
  ``∀ls mn ta. exh_weak (get_exh (FST ta)) (get_exh (FST (alloc_tags mn ta ls)))``,
  Induct >> rw[alloc_tags_def] >>
  PairCases_on`h`>>simp[alloc_tags_def]>>
  qmatch_abbrev_tac`exh_weak X (get_exh (FST (alloc_tags mn ta' ls)))` >>
  qunabbrev_tac`X` >>
  first_x_assum(qspecl_then[`mn`,`ta'`]mp_tac) >>
  `exh_weak (get_exh (FST ta)) (get_exh (FST ta'))` suffices_by metis_tac[exh_weak_trans] >>
  rw[Abbr`ta'`] >>
  qid_spec_tac`ta` >>
  Induct_on`h2` >> rw[] >>
  fs[UNCURRY] >>
  qpat_abbrev_tac`ta' = alloc_tag X Y Z ta` >>
  first_x_assum(qspec_then`ta'`mp_tac) >> rw[] >>
  rw[Abbr`ta'`] >>
  metis_tac[alloc_tag_exh_weak,exh_weak_trans])

val compile_decs_exh_weak = store_thm("compile_decs_exh_weak",
  ``∀ds (st:tagenv_state_acc).
      exh_weak (get_exh (FST st)) (get_exh (FST (FST (compile_decs st ds))))``,
  Induct >> simp[compile_decs_def] >> rw[] >>
  every_case_tac >> simp[UNCURRY] >>
  metis_tac[exh_weak_trans,alloc_tag_exh_weak,alloc_tags_exh_weak])

val alloc_tag_exh_wf = store_thm("alloc_tag_exh_wf",
  ``exh_wf (get_exh (FST st)) ⇒ exh_wf (get_exh (FST (alloc_tag a b c st)))``,
  `∃next menv env exh acc. st = ((next,(menv,env),exh),acc)` by metis_tac[PAIR] >>
  simp[alloc_tag_def]>>
  every_case_tac >> simp[UNCURRY,get_exh_def,exh_wf_def] >> rw[] >>
  fs[IN_FRANGE_FLOOKUP,PULL_EXISTS,DOMSUB_FLOOKUP_THM] >>
  res_tac >> fs[] >>
  match_mp_tac sptreeTheory.wf_insert >>
  simp[sptreeTheory.wf_def])

val alloc_tags_exh_wf = store_thm("alloc_tags_exh_wf",
  ``∀ls mn ta. exh_wf (get_exh (FST ta)) ⇒ exh_wf (get_exh (FST (alloc_tags mn ta ls)))``,
  Induct >> rw[alloc_tags_def] >>
  PairCases_on`h`>>simp[alloc_tags_def]>>
  qmatch_abbrev_tac`exh_wf (get_exh (FST (alloc_tags mn ta' ls)))` >>
  first_x_assum(qspecl_then[`mn`,`ta'`]match_mp_tac) >>
  rw[Abbr`ta'`] >>
  pop_assum mp_tac >>
  qid_spec_tac`ta` >>
  Induct_on`h2` >> rw[] >>
  fs[UNCURRY] >>
  qpat_abbrev_tac`ta' = alloc_tag X Y Z ta` >>
  first_x_assum(qspec_then`ta'`mp_tac) >> rw[] >>
  first_x_assum match_mp_tac >>
  rw[Abbr`ta'`] >>
  metis_tac[alloc_tag_exh_wf])

val compile_decs_exh_wf = store_thm("compile_decs_exh_wf",
  ``∀ds st.
      exh_wf (get_exh (FST st)) ⇒ exh_wf (get_exh (FST (FST (compile_decs st ds))))``,
  Induct >> simp[compile_decs_def] >> rw[] >>
  every_case_tac >> simp[UNCURRY] >>
  metis_tac[alloc_tag_exh_wf,alloc_tags_exh_wf])

val alloc_tags_next = store_thm("alloc_tags_next",
  ``∀x st z. FST (FST (alloc_tags x st z)) = FST (FST st)``,
  ho_match_mp_tac alloc_tags_ind >>
  rw[alloc_tags_def] >> rw[] >>
  rw[Abbr`st'`] >>
  qid_spec_tac`st` >>
  pop_assum kall_tac >>
  qid_spec_tac`constrs` >>
  Induct_on`constrs` >>
  rw[] >>
  PairCases_on`st`>>rw[alloc_tag_def] >>
  simp[UNCURRY])

val compile_decs_next_weak = store_thm("compile_decs_next_weak",
  ``next_weak (FST(FST st)) (FST(FST(FST (compile_decs (st:tagenv_state_acc) ds))))``,
  qid_spec_tac`st`>>Induct_on`ds`>>
  rw[compile_decs_def] >- rw[next_weak_def] >>
  Cases_on`h`>>simp[UNCURRY] >- (
    match_mp_tac (GEN_ALL next_weak_trans) >>
    qpat_abbrev_tac`st1:tagenv_state_acc = alloc_tags X Y Z` >>
    first_x_assum(qspec_then`st1`strip_assume_tac) >>
    ONCE_REWRITE_TAC[CONJ_COMM] >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    simp[Abbr`st1`,alloc_tags_next] >>
    simp[next_weak_def] ) >>
  match_mp_tac (GEN_ALL next_weak_trans) >>
  qpat_abbrev_tac`st1:tagenv_state_acc = alloc_tag A X Y Z` >>
  first_x_assum(qspec_then`st1`strip_assume_tac) >>
  ONCE_REWRITE_TAC[CONJ_COMM] >>
  first_assum(match_exists_tac o concl) >> simp[] >>
  rw[Abbr`st1`] >>
  PairCases_on`st`>>rw[alloc_tag_def] >>
  simp[next_weak_def,sptreeTheory.lookup_insert] >>
  rw[] >>
  simp[Abbr`tag`])

val alloc_tag_cenv_inv = prove(
  ``cenv_inv envC (get_exh (FST st)) (get_tagenv st) gtagenv ∧
    next_inv tids (FST (FST st)) gtagenv ∧
    (cn,tn) ∉ FDOM gtagenv ∧
    (∀x. tn = TypeExn x ⇒ cn = id_to_n x) ⇒
    ∃gtagenv'.
      cenv_inv (merge_alist_mod_env ([],[(cn,arity,tn)]) envC)
        (get_exh (FST (alloc_tag tn cn arity st)))
        (get_tagenv (alloc_tag tn cn arity st))
        gtagenv' ∧
      next_inv (tn INSERT tids) (FST (FST (alloc_tag tn cn arity st))) gtagenv' ∧
      gtagenv ⊑ gtagenv' ∧
      FDOM gtagenv' = FDOM gtagenv ∪ {(cn,tn)}``,
  `∃next tagenv exh acc. st = ((next,tagenv,exh),acc)` by metis_tac[PAIR] >>
  `∃env menv. envC = (menv,env)` by metis_tac[PAIR] >>
  simp[merge_alist_mod_env_def] >> strip_tac >>
  Cases_on`tn` >>
  simp[alloc_tag_def,UNCURRY,get_exh_def,get_tagenv_def] >- (
    qpat_abbrev_tac`tagexh:num#exh_ctors_env = X Y` >>
    qexists_tac`gtagenv |+ ((cn,TypeId i),(FST tagexh,arity))` >>
    reverse conj_tac >- (
      conj_tac >- (
        fs[next_inv_def,FLOOKUP_UPDATE] >>
        metis_tac[SUBSET_INSERT_RIGHT] ) >>
      simp[] >> simp[EXTENSION] >>
      metis_tac[] ) >>
    fs[cenv_inv_def] >>
    conj_tac >- (
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[envC_tagged_def] >>
      reverse Cases >> simp[lookup_alist_mod_env_def] >- (
        first_x_assum(qspec_then`Long s a`mp_tac) >>
        simp[lookup_alist_mod_env_def] >> strip_tac >>
        rpt gen_tac >>
        BasicProvers.CASE_TAC >> fs[] >>
        strip_tac >> fs[] >>
        `∃mtagenv ftagenv. tagenv = (mtagenv,ftagenv)` by metis_tac[PAIR]>>
        simp[insert_tag_env_def,lookup_tag_env_def] >>
        fs[get_tagenv_def,lookup_tag_env_def] >>
        simp[FLOOKUP_UPDATE] >>
        fs[astTheory.id_to_n_def] >>
        fs[get_exh_def,exhaustive_env_correct_def,PULL_EXISTS] >>
        IF_CASES_TAC >> simp[] >> fs[] >>
        rpt BasicProvers.VAR_EQ_TAC >>
        fs[FLOOKUP_DEF] ) >>
      rpt gen_tac >>
      `∃mtagenv ftagenv. tagenv = (mtagenv,ftagenv)` by metis_tac[PAIR]>>
      rw[insert_tag_env_def,lookup_tag_env_def,lookup_tag_flat_def,FLOOKUP_UPDATE,astTheory.id_to_n_def] >>
      first_x_assum(qspec_then`Short a`mp_tac) >>
      simp[lookup_alist_mod_env_def] >> strip_tac >>
      fs[lookup_tag_env_def,get_tagenv_def,lookup_tag_flat_def] >>
      fs[astTheory.id_to_n_def] ) >>
    conj_tac >- (
      fs[exhaustive_env_correct_def,get_exh_def,PULL_EXISTS] >>
      conj_tac >- (
        simp[Abbr`tagexh`] >>
        every_case_tac >> simp[] >> rw[] >>
        TRY(
          match_mp_tac sptreeTheory.wf_insert >>
          rw[sptreeTheory.wf_def] >>
          fs[IN_FRANGE_FLOOKUP,PULL_EXISTS] >>
          first_x_assum match_mp_tac >>
          first_assum(match_exists_tac o concl) >>
          rw[] >> NO_TAC) >>
        pop_assum mp_tac >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        rw[] ) >>
      (*
      conj_tac >- (
        fs[SUBSET_DEF,EXISTS_PROD] >>
        simp[Abbr`tagexh`] >>
        every_case_tac >> simp[] >>
        metis_tac[] ) >>
      *)
      rw[Abbr`tagexh`] >- (
        every_case_tac  >> simp[FLOOKUP_UPDATE,sptreeTheory.lookup_insert] >> rw[] >>
        first_x_assum(qspecl_then[`i`,`cn'`]mp_tac) >>
        (discharge_hyps >- fs[FLOOKUP_DEF]) >> rw[] >>
        res_tac >> fs[] >> rw[] >> simp[] ) >>
      every_case_tac >> simp[FLOOKUP_UPDATE] >> rw[sptreeTheory.lookup_insert] >>
      every_case_tac >> fs[] >> rw[] >> fs[] >>
      TRY (
        qmatch_assum_rename_tac`FLOOKUP gtagenv (cnz,TypeId i) = SOME (tag,az)` >>
        first_x_assum(qspecl_then[`i`,`cnz`]mp_tac) >>
        (discharge_hyps >- fs[FLOOKUP_DEF]) >> rw[] >>
        res_tac >> fs[] >> simp[]) >>
      res_tac >> fs[] >>
      metis_tac[] ) >>
    fs[gtagenv_wf_def] >>
    conj_tac >- fs[has_exns_def,FLOOKUP_UPDATE] >>
    conj_tac >- (
      fs[has_bools_def,FLOOKUP_UPDATE] >>
      rw[] >> fs[FLOOKUP_DEF] ) >>
    conj_tac >- (
      fs[has_lists_def,FLOOKUP_UPDATE] >>
      rw[] >> fs[FLOOKUP_DEF] ) >>
    simp[FLOOKUP_UPDATE] >>
    simp[Abbr`tagexh`] >>
    rpt gen_tac >>
    every_case_tac >> fs[same_tid_tid] >> rpt BasicProvers.VAR_EQ_TAC >> simp[same_tid_tid] >>
    spose_not_then strip_assume_tac >> rpt BasicProvers.VAR_EQ_TAC >>
    fs[exhaustive_env_correct_def,get_exh_def,PULL_EXISTS] >>
    qmatch_assum_rename_tac`FLOOKUP gtagenv (cnz,TypeId i) = SOME _` >>
    last_x_assum(qspecl_then[`i`,`cnz`]mp_tac) >>
    (discharge_hyps >- fs[FLOOKUP_DEF] >> rw[]) >>
    first_assum(match_exists_tac o concl) >>
    simp[] ) >>
  qpat_abbrev_tac`tag:num = X Y` >>
  qexists_tac`gtagenv |+ ((cn,TypeExn i),(tag,arity))` >>
  reverse conj_tac >- (
    conj_tac >- (
      fs[next_inv_def,FLOOKUP_UPDATE,sptreeTheory.lookup_insert,Abbr`tag`] >>
      reverse conj_tac >- (
        metis_tac[SUBSET_INSERT_RIGHT] ) >>
      rpt gen_tac >> every_case_tac >> rw[] >> fs[] >>
      res_tac >> fs[] >> rw[] >> simp[] ) >>
    simp[] >> simp[EXTENSION] >>
    metis_tac[] ) >>
  fs[cenv_inv_def] >>
  rpt BasicProvers.VAR_EQ_TAC >>
  conj_tac >- (
    fs[envC_tagged_def] >>
    reverse Cases >> simp[lookup_alist_mod_env_def] >- (
      first_x_assum(qspec_then`Long s a`mp_tac) >>
      simp[lookup_alist_mod_env_def] >> strip_tac >>
      rpt gen_tac >>
      BasicProvers.CASE_TAC >> fs[] >>
      strip_tac >> fs[] >>
      `∃mtagenv ftagenv. tagenv = (mtagenv,ftagenv)` by metis_tac[PAIR]>>
      simp[insert_tag_env_def,lookup_tag_env_def] >>
      fs[get_tagenv_def,lookup_tag_env_def] >>
      simp[FLOOKUP_UPDATE] >>
      fs[astTheory.id_to_n_def] >>
      fs[get_exh_def,exhaustive_env_correct_def,PULL_EXISTS] >>
      IF_CASES_TAC >> simp[] >> fs[] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[FLOOKUP_DEF] ) >>
    rpt gen_tac >>
    `∃mtagenv ftagenv. tagenv = (mtagenv,ftagenv)` by metis_tac[PAIR]>>
    rw[insert_tag_env_def,lookup_tag_env_def,lookup_tag_flat_def,FLOOKUP_UPDATE,astTheory.id_to_n_def] >>
    first_x_assum(qspec_then`Short a`mp_tac) >>
    simp[lookup_alist_mod_env_def] >> strip_tac >>
    fs[lookup_tag_env_def,get_tagenv_def,lookup_tag_flat_def] >>
    fs[astTheory.id_to_n_def] ) >>
  conj_tac >- (
    fs[exhaustive_env_correct_def,get_exh_def,PULL_EXISTS] >>
    (* conj_tac >- (fs[SUBSET_DEF] >> metis_tac[]) >> *)
    rw[] >> res_tac >> simp[] >>
    simp[FLOOKUP_UPDATE] >>
    metis_tac[] ) >>
  fs[gtagenv_wf_def] >>
  conj_tac >- (
    fs[has_exns_def,FLOOKUP_UPDATE] >>
    rw[] >> fs[FLOOKUP_DEF] ) >>
  conj_tac >- fs[has_bools_def,FLOOKUP_UPDATE] >>
  conj_tac >- fs[has_lists_def,FLOOKUP_UPDATE] >>
  simp[FLOOKUP_UPDATE] >>
  conj_tac >- (
    Cases >> Cases >> simp[same_tid_def,FLOOKUP_UPDATE] >- (
      metis_tac[same_tid_refl] ) >>
    simp[Abbr`tag`] >>
    rpt gen_tac >>
    fs[next_inv_def] >>
    every_case_tac >> fs[] >> rw[] >>
    spose_not_then strip_assume_tac >> rpt BasicProvers.VAR_EQ_TAC >>
    res_tac >> fs[same_tid_def] >> rw[] >> fs[]) >>
  rw[] >> metis_tac[])

val FOLDL_alloc_tag_cenv_inv = prove(
  ``∀(constrs:(conN # t list) list) envC st gtagenv tids.
    cenv_inv envC (get_exh (FST st)) (get_tagenv st) gtagenv ∧
    next_inv tids (FST (FST st)) gtagenv ∧
    (∀cn. MEM cn (MAP FST constrs) ⇒ (cn,TypeId(mk_id mn tn)) ∉ FDOM gtagenv) ∧
    ALL_DISTINCT (MAP FST constrs)
    ⇒
    let st' = FOLDL (λst (cn,ts). alloc_tag (TypeId (mk_id mn tn)) cn (LENGTH ts) st) st constrs in
    ∃gtagenv'.
    cenv_inv
      (merge_alist_mod_env ([],REVERSE (MAP (λ(cn,ts). (cn,LENGTH ts,TypeId (mk_id mn tn))) constrs)) envC)
      (get_exh (FST st'))
      (get_tagenv st')
      gtagenv' ∧
    next_inv (TypeId(mk_id mn tn) INSERT tids) (FST (FST st')) gtagenv' ∧
    gtagenv ⊑ gtagenv' ∧
    FDOM gtagenv' = FDOM gtagenv ∪ { (cn,TypeId(mk_id mn tn)) | MEM cn (MAP FST constrs) }``,
  ho_match_mp_tac SNOC_INDUCT >>
  conj_tac >- (
    simp[merge_alist_mod_env_empty] >>
    metis_tac[SUBMAP_REFL,next_inv_tids_subset,INSERT_SUBSET,SUBSET_REFL] ) >>
  rw[FOLDL_SNOC] >>
  rw[MAP_SNOC,REVERSE_SNOC] >>
  `∃cn ts. x = (cn,ts)` by metis_tac[PAIR] >>
  fs[] >> BasicProvers.VAR_EQ_TAC >>
  first_x_assum(qspecl_then[`envC`,`st`,`gtagenv`,`tids`]mp_tac) >>
  discharge_hyps >- (
    fs[MAP_SNOC,ALL_DISTINCT_SNOC] ) >>
  BasicProvers.LET_ELIM_TAC >> rfs[] >>
  first_x_assum(mp_tac o MATCH_MP(
    GEN_ALL(ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]alloc_tag_cenv_inv))) >>
  disch_then(qspecl_then[`TypeId(mk_id mn tn)`,`TypeId (mk_id mn tn) INSERT tids`,`cn`,`LENGTH ts`]mp_tac) >>
  discharge_hyps >- (
    fs[MAP_SNOC,ALL_DISTINCT_SNOC] >>
    Cases_on`envC`>>fs[merge_alist_mod_env_def]) >>
  simp[merge_alist_mod_env_assoc,merge_alist_mod_env_def] >>
  strip_tac >>
  first_assum(match_exists_tac o concl) >>
  simp[] >>
  simp[EXTENSION] >>
  metis_tac[SUBMAP_TRANS] )

val union_insert_lem = prove(
  ``a ∪ (b INSERT c) = (a ∪ {b}) ∪ c``,
  rw[EXTENSION] >> metis_tac[])

val alloc_tags_cenv_inv = prove(
  ``∀mn st (ls:(tvarN list # typeN # (conN # t list) list) list) envC gtagenv tids.
    cenv_inv envC (get_exh (FST st)) (get_tagenv st) gtagenv ∧
    next_inv tids (FST (FST st)) gtagenv ∧
    (* new types only *)
    DISJOINT (set (MAP (TypeId o mk_id mn o FST o SND) ls)) (IMAGE SND (FDOM gtagenv))
    ∧ ALL_DISTINCT (MAP (FST o SND) ls)
    ∧ check_dup_ctors ls
    ⇒
    ∃gtagenv'.
    cenv_inv (merge_alist_mod_env ([],build_tdefs mn ls) envC)
      (get_exh (FST (alloc_tags mn st ls)))
      (get_tagenv (alloc_tags mn st ls))
      gtagenv' ∧
    next_inv (tids ∪ type_defs_to_new_tdecs mn ls) (FST (FST (alloc_tags mn st ls))) gtagenv' ∧
    gtagenv_weak gtagenv gtagenv' ∧
    IMAGE SND (FDOM gtagenv') = IMAGE SND (FDOM gtagenv)
      ∪ IMAGE (TypeId o mk_id mn o FST o SND)
        (set (FILTER ($~ o NULL o SND o SND) ls))``,
  ho_match_mp_tac alloc_tags_ind >>
  conj_tac >- (
    simp[alloc_tags_def,build_tdefs_def,merge_alist_mod_env_empty,get_exh_def,get_tagenv_def,type_defs_to_new_tdecs_def] >>
    metis_tac[cenv_inv_def,gtagenv_weak_refl] ) >>
  rpt gen_tac >>
  qpat_abbrev_tac`tagenv_st:tagenv_state_acc = FOLDL X Y Z` >>
  reverse(rw[build_tdefs_cons]) >- (
    Cases_on`constrs`>>fs[] >>
    simp[alloc_tags_def] >>
    fs[type_defs_to_new_tdecs_def,Once union_insert_lem] >>
    first_x_assum match_mp_tac >>
    rfs[] >>
    fs[terminationTheory.check_dup_ctors_thm] >>
    match_mp_tac (GEN_ALL next_inv_tids_subset) >>
    qexists_tac`tids`>>simp[]) >>
  first_x_assum(qspecl_then[`constrs`,`tids`]mp_tac o
    MATCH_MP(ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]FOLDL_alloc_tag_cenv_inv)) >>
  discharge_hyps >- (
    fs[terminationTheory.check_dup_ctors_thm,ALL_DISTINCT_APPEND,FST_pair] >>
    metis_tac[SND] ) >>
  simp[] >> strip_tac >>
  simp[alloc_tags_def] >>
  first_x_assum(fn th =>
    first_assum(mp_tac o MATCH_MP(ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO] th))) >>
  disch_then(qspec_then`TypeId(mk_id mn tn) INSERT tids`mp_tac) >>
  discharge_hyps >- (
    imp_res_tac check_dup_ctors_cons >>
    simp[] >>
    conj_tac >- metis_tac[DISJOINT_SYM] >>
    fs[terminationTheory.check_dup_ctors_thm,ALL_DISTINCT_APPEND] >>
    fs[IN_DISJOINT,MEM_FLAT,MEM_MAP,PULL_EXISTS,FORALL_PROD] >>
    spose_not_then strip_assume_tac >> rw[] >>
    fs[mk_id_11] >> rw[] >>
    metis_tac[] ) >>
  simp[merge_alist_mod_env_assoc,merge_alist_mod_env_def] >>
  strip_tac >>
  first_assum (match_exists_tac o concl) >> simp[] >>
  conj_tac >- (
    Cases_on`envC`>>fs[merge_alist_mod_env_def] >>
    fs[type_defs_to_new_tdecs_def,GSYM union_insert_lem,Once INSERT_SING_UNION] >>
    metis_tac[UNION_ASSOC,UNION_COMM]) >>
  conj_tac >- (
    match_mp_tac gtagenv_weak_trans >>
    ONCE_REWRITE_TAC[CONJ_COMM] >>
    first_assum(match_exists_tac o concl) >> rw[] >>
    simp[gtagenv_weak_def] >>
    reverse conj_tac >- (
      fs[cenv_inv_def,gtagenv_wf_def] >>
      metis_tac[] ) >>
    metis_tac[SND] ) >>
  simp[EXTENSION,PULL_EXISTS] >>
  rw[EQ_IMP_THM] >>
  TRY(metis_tac[]) >>
  simp[mk_id_11,EXISTS_PROD,MEM_FILTER] >>
  fs[NOT_NULL_MEM,MEM_MAP] >>
  metis_tac[])

val recfun_helper = Q.prove (
  `cenv_inv envC exh tagenv gtagenv
   ⇒
   LIST_REL (OPTREL (v_rel gtagenv))
            (MAP SOME (MAP (\(f:string,x,e). Closure (envC,[]) x e) l))
            (MAP SOME (MAP (\(f,x,e). Closure [] x (compile_exp tagenv e)) l))`,
  induct_on `l` >>
  rw [] >>
  PairCases_on `h` >>
  rw [] >>
  rw [OPTREL_def] >>
  rw [Once v_rel_cases, v_rel_eqns] >>
  metis_tac []);

val compile_decs_correct = store_thm("compile_decs_correct",
  ``∀env s ds r.
      evaluate_decs env s ds = r ⇒
    ∀res s1_i2 tagenv_st ds_i2 tagenv_st' genv' envC' s' gtagenv.
      r = (s', envC', genv', res) ∧
      res ≠ SOME (Rabort Rtype_error) ∧
      no_dup_types ds ∧
      compile_decs tagenv_st ds = (tagenv_st', ds_i2) ∧
      cenv_inv env.c (get_exh (FST tagenv_st)) (get_tagenv tagenv_st) gtagenv ∧
      s_rel gtagenv s s1_i2 ∧
      next_inv s.defined_types (FST (FST tagenv_st)) gtagenv
      ⇒
      ∃genv'_i2 s'_i2 res_i2 gtagenv' acc'.
        evaluate_decs <| exh := get_exh (FST tagenv_st'); v := []|> s1_i2 ds_i2 = (s'_i2,genv'_i2,res_i2) ∧
        gtagenv_weak gtagenv gtagenv' ∧
        vs_rel gtagenv' genv' genv'_i2 ∧
        s_rel gtagenv' s' s'_i2 ∧
        next_inv s'.defined_types (FST (FST tagenv_st')) gtagenv' ∧
        SND tagenv_st' = FUNION acc' (SND tagenv_st) ∧
        gtagenv_wf gtagenv' ∧
        exhaustive_env_correct (get_exh (FST tagenv_st')) gtagenv' ∧
        (res = NONE ∧ res_i2 = NONE ∧ FDOM acc' = set (MAP FST envC') ∧
         flat_envC_tagged envC' acc' gtagenv'
         ∨
         (∃err err_i2.
           res = SOME err ∧ res_i2 = SOME err_i2 ∧
           s_rel gtagenv' s' s'_i2 ∧
           result_rel v_rel gtagenv' (Rerr err) (Rerr err_i2)))``,
  Induct_on`ds` >- (
    simp[modSemTheory.evaluate_decs_def,compile_decs_def,conSemTheory.evaluate_decs_def] >>
    simp[FDOM_EQ_EMPTY,vs_rel_list_rel,flat_envC_tagged_def] >>
    simp[cenv_inv_def] >> metis_tac[gtagenv_weak_refl] ) >>
  simp[modSemTheory.evaluate_decs_def] >>
  rpt gen_tac >>
  (fn g => valOf(bvk_find_term (K true) split_pair_case_tac (#2 g)) g) >> simp[] >>
  reverse BasicProvers.CASE_TAC >- (
    strip_tac >>
    rpt var_eq_tac >>
    simp[vs_rel_list_rel] >>
    simp[PULL_EXISTS] >> fs[] >>
    fs[compile_decs_def] >>
    Cases_on`h`>>fs[modSemTheory.evaluate_dec_def,LET_THM] >>
    every_case_tac >> fs[] >>
    rpt var_eq_tac >>
    first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >>
    rpt var_eq_tac >>
    first_assum(mp_tac o MATCH_MP(CONJUNCT1 compile_exp_correct)) >>
    simp[] >>
    simp[env_all_rel_cases] >>
    imp_res_tac tagacc_accumulates >>
    qpat_abbrev_tac`env_i2:conSem$environment = _` >>
    disch_then(qspec_then`env_i2`mp_tac o (CONV_RULE(RESORT_FORALL_CONV(sort_vars["env_i2"])))) >>
    simp[env_rel_el,LENGTH_NIL_SYM] >>
    simp[Abbr`env_i2`] >>
    CONV_TAC(LAND_CONV(STRIP_QUANT_CONV(LAND_CONV(lift_conjunct_conv(same_const``s_rel`` o fst o strip_comb))))) >>
    simp[Once(GSYM AND_IMP_INTRO)] >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >> simp[] >>
    disch_then(qspec_then`get_tagenv tagenv_st`mp_tac) >>
    discharge_hyps_keep >- (
      fs[cenv_inv_def] >> simp[gtagenv_weak_refl] >>
      match_mp_tac (GEN_ALL exhaustive_env_correct_exh_weak) >>
      first_assum(match_exists_tac o concl) >> simp[] >>
      fs[exhaustive_env_correct_def,GSYM exh_wf_def] >>
      metis_tac[compile_decs_exh_wf,compile_decs_exh_weak,FST]) >>
    simp[compile_exps_map] >>
    strip_tac >>
    simp[conSemTheory.evaluate_decs_def,conSemTheory.evaluate_dec_def] >>
    BasicProvers.CASE_TAC>-fs[result_rel_cases]>>simp[] >>
    fs[cenv_inv_def] >>
    qexists_tac`gtagenv`>>simp[] >>
    simp[GSYM PULL_EXISTS] >>
    conj_tac >- metis_tac[gtagenv_weak_refl] >>
    reverse conj_tac >- (
      fs[result_rel_cases] >>
      metis_tac[] ) >>
    imp_res_tac modPropsTheory.evaluate_state_const >> simp[] >>
    fs[next_inv_def] >>
    last_x_assum kall_tac >>
    rw[] >> res_tac >>
    PairCases_on`tagenv_st` >> PairCases_on`st'` >>
    `next_weak tagenv_st0 st'0` by metis_tac[compile_decs_next_weak,FST] >>
    fs[next_weak_def] >> res_tac >> simp[] ) >>
  BasicProvers.CASE_TAC >>
  (fn g => valOf(bvk_find_term (K true) split_pair_case_tac (#2 g)) g) >> simp[] >>
  rw[] >>
  imp_res_tac modPropsTheory.no_dup_types_cons_imp >>
  rator_x_assum`mod_to_con$compile_decs`mp_tac >>
  simp[compile_decs_def] >>
  BasicProvers.CASE_TAC >> strip_tac >>
  first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >>
  rpt BasicProvers.VAR_EQ_TAC >>
  first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
  fs[modSemTheory.evaluate_dec_def] >> rpt BasicProvers.VAR_EQ_TAC >>
  disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
  every_case_tac >> fs[LET_THM] >> rpt var_eq_tac >> simp[]
  >- (
    first_assum(mp_tac o MATCH_MP (CONJUNCT1 compile_exp_correct)) >>
    simp[env_all_rel_cases,PULL_EXISTS] >>
    CONV_TAC(LAND_CONV(STRIP_QUANT_CONV(LAND_CONV(lift_conjunct_conv(same_const``s_rel`` o fst o strip_comb))))) >>
    simp[GSYM AND_IMP_INTRO,env_rel_el,LENGTH_NIL_SYM] >>
    simp[Once result_rel_cases,PULL_EXISTS,vs_rel_list_rel] >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(qspec_then`get_tagenv tagenv_st`mp_tac) >>
    qpat_abbrev_tac`env_i2:conSem$environment = _ with v := _` >>
    disch_then(qspec_then`env_i2`mp_tac) >>
    simp[Abbr`env_i2`] >>
    discharge_hyps_keep >- (
      fs[cenv_inv_def] >> simp[gtagenv_weak_refl] >>
      match_mp_tac (GEN_ALL exhaustive_env_correct_exh_weak) >>
      first_assum(match_exists_tac o concl) >> simp[] >>
      fs[exhaustive_env_correct_def,GSYM exh_wf_def] >>
      metis_tac[compile_decs_exh_wf,compile_decs_exh_weak,FST]) >>
    simp[compile_exps_map] >>
    simp[v_rel_eqns,PULL_EXISTS,vs_rel_list_rel] >>
    rpt gen_tac >> strip_tac >>
    imp_res_tac LIST_REL_LENGTH >>
    simp[conSemTheory.evaluate_decs_def,conSemTheory.evaluate_dec_def] >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    qpat_abbrev_tac`s_i2:'ffi conSem$state = _ with globals updated_by _` >>
    disch_then(qspec_then`s_i2`mp_tac) >>
    discharge_hyps >- (
      simp[Abbr`s_i2`] >>
      fs[s_rel_cases] >>
      MATCH_MP_TAC EVERY2_APPEND_suff >>
      simp[EVERY2_MAP,optionTheory.OPTREL_def] >>
      simp_tac(srw_ss()++boolSimps.ETA_ss)[] >> rw[] ) >>
    discharge_hyps >- (
      imp_res_tac modPropsTheory.evaluate_state_const >> simp[] ) >>
    simp[PULL_EXISTS] >> rpt gen_tac >>
    simp[GSYM AND_IMP_INTRO] >>
    ntac 8 strip_tac >>
    qpat_abbrev_tac`D ⇔ a ∨ b` >>
    strip_tac >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    qexists_tac`acc'`>>simp[] >>
    match_mp_tac EVERY2_APPEND_suff >> simp[] >>
    metis_tac[v_rel_weakening,vs_rel_list_rel] )
  >- (
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    simp[conSemTheory.evaluate_decs_def,conSemTheory.evaluate_dec_def] >>
    qpat_abbrev_tac`s_i2:'ffi conSem$state = _ with globals updated_by _` >>
    disch_then(qspec_then`s_i2`mp_tac) >>
    discharge_hyps >- (
      fs[s_rel_cases,Abbr`s_i2`] >>
      simp[compile_funs_map] >>
      fs[MAP_MAP_o,o_DEF,UNCURRY] >>
      match_mp_tac EVERY2_APPEND_suff >> simp[] >>
      fs[EVERY2_MAP,optionTheory.OPTREL_def,UNCURRY] >>
      match_mp_tac (MP_CANON (GEN_ALL LIST_REL_mono)) >>
      simp[Once v_rel_cases] >>
      qexists_tac`$=`>>simp[env_rel_el] >>
      simp[LIST_REL_EL_EQN] >>
      metis_tac[] ) >>
    simp[] >> unabbrev_all_tac >>
    simp[PULL_EXISTS] >> rpt gen_tac >>
    qpat_abbrev_tac`D ⇔ a ∨ b` >> strip_tac >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    fs[vs_rel_list_rel] >>
    qexists_tac`acc'`>>simp[]>>
    reverse conj_tac >- ( fs[markerTheory.Abbrev_def] ) >>
    match_mp_tac EVERY2_APPEND_suff >> simp[] >>
    simp[compile_funs_map] >>
    fs[MAP_MAP_o,o_DEF,UNCURRY] >>
    fs[EVERY2_MAP,optionTheory.OPTREL_def,UNCURRY] >>
    simp[Once v_rel_cases,env_rel_el] >>
    simp[LIST_REL_EL_EQN] >> rw[] >>
    fs[cenv_inv_def] >>
    fs[envC_tagged_def] >>
    PROVE_TAC[gtagenv_weak_def,FLOOKUP_SUBMAP])
  >- (
    first_x_assum(mp_tac o MATCH_MP(ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]alloc_tags_cenv_inv)) >>
    qmatch_assum_rename_tac`compile_decs (alloc_tags mn tagenv_st ls) ds = _` >>
    disch_then(qspecl_then[`mn`,`ls`,`s.defined_types`]mp_tac) >>
    discharge_hyps >- (
      every_case_tac >> fs[] >>
      simp[combinTheory.o_DEF,LAMBDA_PROD] >>
      PairCases_on`tagenv_st`>>
      fs[next_inv_def] >>
      fs[type_defs_to_new_tdecs_def,IN_DISJOINT,SUBSET_DEF] >>
      metis_tac[] ) >>
    strip_tac >>
    every_case_tac >> fs[] >>
    rpt var_eq_tac >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
    disch_then(qspecl_then[`s1_i2`]mp_tac) >>
    discharge_hyps >- (
      fs[s_rel_cases] >>
      conj_tac >>
      match_mp_tac (GEN_ALL(MP_CANON LIST_REL_mono)) >>
      metis_tac[sv_rel_weakening,v_rel_weakening,OPTREL_MONO] ) >>
    discharge_hyps >- (
      simp[] >>
      Cases_on`env.c`>>fs[merge_alist_mod_env_def] >>
      simp[Once UNION_COMM] ) >>
    simp[PULL_EXISTS] >> rpt gen_tac >>
    qpat_abbrev_tac`D ⇔ a ∨ b` >> strip_tac >>
    qexists_tac`gtagenv''` >> simp[] >>
    qspecl_then[`ls`,`mn`,`tagenv_st`]strip_assume_tac alloc_tags_accumulates >>
    qexists_tac`acc' ⊌ acc` >>
    conj_tac >- metis_tac[gtagenv_weak_trans] >>
    conj_tac >- metis_tac[FUNION_ASSOC] >>
    qunabbrev_tac`D` >> fs[] >>
    `∃next tagenv exh acc. alloc_tags mn tagenv_st ls = ((next,tagenv,exh),acc)` by metis_tac[PAIR] >>
    fs[cenv_inv_def] >>
    imp_res_tac envC_tagged_flat_envC_tagged >>
    fs[flat_envC_tagged_def] >>
    fs[ALOOKUP_APPEND] >>
    rpt gen_tac >>
    BasicProvers.CASE_TAC >- (
      strip_tac >>
      first_x_assum(qspec_then`cn`mp_tac) >>
      first_x_assum(qspec_then`cn`mp_tac) >>
      discharge_hyps >- (
        imp_res_tac ALOOKUP_MEM >>
        simp[MEM_MAP,EXISTS_PROD] >>
        metis_tac[] ) >>
      strip_tac >>
      Cases_on`env.c`>>simp[merge_alist_mod_env_def,ALOOKUP_APPEND]>>
      strip_tac >>
      fs[lookup_tag_flat_def,FLOOKUP_FUNION] >>
      reverse BasicProvers.CASE_TAC >- (
        fs[FLOOKUP_DEF] >>
        imp_res_tac ALOOKUP_FAILS >>
        rfs[MEM_MAP,EXISTS_PROD] >>
        metis_tac[] ) >>
      every_case_tac >> fs[] >- (
        rfs[FLOOKUP_DEF] >>
        imp_res_tac ALOOKUP_MEM >>
        fs[MEM_MAP,EXISTS_PROD] >>
        metis_tac[] ) >>
      fs[get_tagenv_def] >>
      Cases_on`tagenv`>>fs[lookup_tag_env_def] >>
      fs[lookup_tag_flat_def] >>
      fs[gtagenv_weak_def] >>
      metis_tac[FLOOKUP_SUBMAP] ) >>
    strip_tac >> BasicProvers.VAR_EQ_TAC >>
    fs[lookup_tag_flat_def,FLOOKUP_FUNION] >>
    res_tac >> simp[] >>
    BasicProvers.CASE_TAC >> fs[]) >>
  qmatch_assum_rename_tac`no_dup_types (Dexn mn tn ls::ds)` >>
  first_x_assum(qspecl_then[`TypeExn(mk_id mn tn)`,`s.defined_types`,`tn`,`LENGTH ls`]mp_tac o
    MATCH_MP(GEN_ALL(ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]alloc_tag_cenv_inv))) >>
  discharge_hyps >- (
    fs[] >>
    PairCases_on`tagenv_st`>>
    fs[next_inv_def,SUBSET_DEF,PULL_EXISTS,astTheory.id_to_n_def,astTheory.mk_id_def] >>
    conj_tac >- metis_tac[SND] >>
    BasicProvers.CASE_TAC >> simp[]) >>
  strip_tac >>
  `gtagenv_weak gtagenv gtagenv'` by (
    simp[gtagenv_weak_def] >>
    reverse conj_tac >- (
      fs[cenv_inv_def,gtagenv_wf_def] >>
      metis_tac[] ) >>
    PairCases_on`tagenv_st`>>
    fs[next_inv_def,SUBSET_DEF,PULL_EXISTS] >>
    metis_tac[SND] ) >>
  disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >>
  disch_then(qspecl_then[`s1_i2`]mp_tac) >>
  discharge_hyps >- (
    fs[s_rel_cases] >>
    conj_tac >>
    match_mp_tac (GEN_ALL(MP_CANON LIST_REL_mono)) >>
    metis_tac[sv_rel_weakening,v_rel_weakening,OPTREL_MONO] ) >>
  discharge_hyps >- (
    simp[GSYM INSERT_SING_UNION] >>
    Cases_on`envC`>>fs[merge_alist_mod_env_def]) >>
  simp[PULL_EXISTS] >> rpt gen_tac >>
  qpat_abbrev_tac`D ⇔ a ∨ b` >> strip_tac >>
  qexists_tac`gtagenv''` >>
  specl_args_of_then``alloc_tag``alloc_tag_accumulates strip_assume_tac >>
  simp[] >>
  qexists_tac`acc' ⊌ acc` >>
  simp[FUNION_ASSOC] >>
  conj_tac >- metis_tac[gtagenv_weak_trans] >>
  qunabbrev_tac`D` >> fs[] >>
  `∃next tagenv exh acc. alloc_tag (TypeExn (mk_id mn tn)) tn (LENGTH ls) tagenv_st = ((next,tagenv,exh),acc)` by metis_tac[PAIR] >>
  fs[cenv_inv_def] >> imp_res_tac envC_tagged_flat_envC_tagged >>
  fs[flat_envC_tagged_def] >>
  simp[ALOOKUP_APPEND] >>
  rpt gen_tac >>
  Cases_on`ALOOKUP new_tds'' cn`>>fs[]>-(
    strip_tac >>
    rpt BasicProvers.VAR_EQ_TAC >>
    fs[lookup_tag_flat_def,FLOOKUP_FUNION] >>
    reverse BasicProvers.CASE_TAC >- (
      fs[FLOOKUP_DEF] >>
      imp_res_tac ALOOKUP_FAILS >>
      rfs[MEM_MAP,EXISTS_PROD] >>
      metis_tac[] ) >>
    first_x_assum(qspec_then`cn`mp_tac) >>
    first_x_assum(qspec_then`cn`mp_tac) >>
    Cases_on`env.c`>>simp[merge_alist_mod_env_def,get_tagenv_def] >>
    strip_tac >>
    every_case_tac >> fs[] >- (
      rfs[FLOOKUP_DEF] >>
      imp_res_tac ALOOKUP_MEM >>
      fs[MEM_MAP,EXISTS_PROD] >>
      metis_tac[] ) >>
    fs[get_tagenv_def] >>
    Cases_on`tagenv`>>fs[lookup_tag_env_def] >>
    fs[lookup_tag_flat_def] >>
    fs[gtagenv_weak_def] >>
    metis_tac[FLOOKUP_SUBMAP] ) >>
  strip_tac >> BasicProvers.VAR_EQ_TAC >>
  fs[lookup_tag_flat_def,FLOOKUP_FUNION] >>
  res_tac >> simp[] >>
  BasicProvers.CASE_TAC >> fs[])

val alloc_tag_exh_FDOM = Q.prove(
  `∀a b c st.
    FDOM (get_exh (FST (alloc_tag a b c st))) =
    FDOM (get_exh (FST st)) ∪ (case a of TypeId t => {t} | _ => {})`,
  rpt gen_tac >>
  PairCases_on`st`>>rw[alloc_tag_def] >>
  every_case_tac >> simp[get_exh_def] >>
  simp[Once INSERT_SING_UNION,UNION_COMM])

val FOLDL_alloc_tags_exh_FDOM = Q.prove(
  `∀(ls:(tvarN,t list)alist) (st:tagenv_state_acc).
     FDOM (get_exh (FST (
       FOLDL (λst' (cn,ts). alloc_tag (TypeId (mk_id mn tn)) cn (LENGTH ts) st') st ls))) ⊆
     FDOM (get_exh (FST st)) ∪ { (mk_id mn tn) }`,
  ho_match_mp_tac SNOC_INDUCT >>
  simp[FOLDL_SNOC] >> rw[] >>
  simp[UNCURRY] >>
  specl_args_of_then``alloc_tag``alloc_tag_exh_FDOM strip_assume_tac >>
  fs[])

val alloc_tags_exh_FDOM = Q.prove(
  `∀mn (ta:tagenv_state_acc) (ls:type_def).
   FDOM (get_exh (FST (alloc_tags mn ta ls))) ⊆
   FDOM (get_exh (FST ta)) ∪ IMAGE (mk_id mn o FST o SND) (set ls)`,
  ho_match_mp_tac alloc_tags_ind >>
  simp[alloc_tags_def] >> rw[] >>
  qspecl_then[`constrs`,`ta`]strip_assume_tac FOLDL_alloc_tags_exh_FDOM >>
  fs[SUBSET_DEF] >>
  metis_tac[])

val FDOM_compile_decs_exh = prove(
  ``∀ds (st:tagenv_state_acc) st' ds'.
    compile_decs st ds = (st',ds') ⇒
    FDOM (get_exh (FST st')) ⊆ FDOM (get_exh (FST st)) ∪ tids_of_decs ds``,
  Induct >> simp[compile_decs_def,modPropsTheory.tids_of_decs_thm] >>
  rpt gen_tac >>
  every_case_tac >> fs[] >> rw[] >>
  first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >>
  first_x_assum(fn th => first_x_assum(strip_assume_tac o MATCH_MP th)) >- (
    pop_assum mp_tac >>
    specl_args_of_then``alloc_tags``alloc_tags_exh_FDOM strip_assume_tac >>
    fs[SUBSET_DEF] >> rw[] >>
    res_tac >- (
      res_tac >> fs[] >>
      simp[MEM_MAP] >>
      metis_tac[] ) >>
    fs[modPropsTheory.tids_of_decs_def] ) >>
  pop_assum mp_tac >>
  specl_args_of_then``alloc_tag``alloc_tag_exh_FDOM strip_assume_tac >>
  fs[])

val compile_decs_dummy_env_num_defs =prove(
  ``∀ds x y z ds2.
    compile_decs x ds = (y,ds2) ⇒
    decs_to_dummy_env ds = num_defs ds2``,
  Induct >> simp[compile_decs_def,modSemTheory.decs_to_dummy_env_def,conLangTheory.num_defs_def] >>
  rpt gen_tac >>
  BasicProvers.CASE_TAC >> rw[] >>
  first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >>
  first_x_assum(fn th => first_x_assum(strip_assume_tac o MATCH_MP th)) >>
  rw[] >>
  simp[modSemTheory.dec_to_dummy_env_def,conLangTheory.num_defs_def,compile_funs_map]);

val compile_prompt_correct = store_thm("compile_prompt_correct",
  ``!env s prompt s_i2 tagenv_st prompt_i2 genv' envC' s' res gtagenv tagenv_st'.
    evaluate_prompt env s prompt = (s', envC', genv', res) ∧
    res ≠ SOME (Rabort Rtype_error) ∧
    invariant env.c tagenv_st gtagenv s s_i2 ∧
    (tagenv_st', prompt_i2) = compile_prompt tagenv_st prompt
    ⇒
    ?genv'_i2 s'_i2 res_i2 gtagenv' new_envC.
      gtagenv_weak gtagenv gtagenv' ∧
      evaluate_prompt <| exh := (get_exh tagenv_st'); v := [] |>
        s_i2 prompt_i2 = (s'_i2,genv'_i2,res_i2) ∧
      invariant new_envC tagenv_st' gtagenv' (s' with globals := s.globals ++ genv') (s'_i2 with globals := s_i2.globals ++ genv'_i2) ∧
      (res = NONE ∧ res_i2 = NONE ∧ new_envC = (merge_alist_mod_env envC' env.c) ∨
       ?err err_i2. res = SOME err ∧ res_i2 = SOME err_i2 ∧ new_envC = env.c ∧
                    s_rel gtagenv' s' s'_i2 ∧
                    result_rel v_rel gtagenv' (Rerr err) (Rerr err_i2))``,
  rw [compile_prompt_def, LET_THM] >>
  every_case_tac >> fs [] >> rw [] >>
  qcase_tac`Prompt mn ds` >>
  first_assum(split_applied_pair_tac o rhs o concl) >> fs[] >> rw [] >>
  fs[modSemTheory.evaluate_prompt_def, conSemTheory.evaluate_prompt_def, LET_THM] >>
  every_case_tac >> fs [] >> rw [] >>
  first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >>
  rpt var_eq_tac >>
  fs [invariant_def]
  >- (
    first_assum(mp_tac o MATCH_MP compile_decs_correct) >> simp[] >>
    REWRITE_TAC[GSYM AND_IMP_INTRO] >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >> simp[] >>
    rpt(disch_then(fn th => first_assum(mp_tac o MATCH_MP th))) >>
    strip_tac >>
    first_assum(match_exists_tac o concl) >>
    simp[PULL_EXISTS] >>
    fs[get_exh_def] >>
    conj_tac >- (
      Cases_on`env.c`>> Cases_on`mn`>>
      simp[modSemTheory.mod_cenv_def,modSemTheory.update_mod_state_def,merge_alist_mod_env_def] >>
      fs[] >> rpt var_eq_tac >> fs[SUBSET_DEF] >>
      imp_res_tac modPropsTheory.evaluate_decs_state_const >> fs[]) >>
    imp_res_tac FDOM_compile_decs_exh >>
    fs[get_exh_def] >>
    conj_tac >- (
      imp_res_tac modPropsTheory.evaluate_decs_tids >> fs[] >>
      imp_res_tac modPropsTheory.evaluate_decs_tids_acc >> fs[] >>
      rw[] >> fs[SUBSET_DEF] >>
      res_tac >> fs[] >>
      fs[EXTENSION] ) >>
    conj_tac >- (
      rw[] >> fs[SUBSET_DEF] >>
      res_tac >- (
        res_tac >>
        Cases_on`mn`>>simp[modSemTheory.update_mod_state_def] >>
        imp_res_tac modPropsTheory.evaluate_decs_state_const >> fs[]) >>
      fs[modPropsTheory.tids_of_decs_def,MEM_FLAT,MEM_MAP,modSemTheory.prompt_mods_ok_def,EVERY_MEM] >>
      first_x_assum(qspec_then`d`mp_tac) >>
      simp[] >> BasicProvers.CASE_TAC >> fs[] >>
      rw[] >> fs[MEM_MAP] >>
      Cases_on`mn`>>fs[astTheory.mk_id_def] >>
      rw[modSemTheory.update_mod_state_def] ) >>
    conj_tac >- (
      fs[cenv_inv_def] >>
      simp[get_tagenv_def] >>
      match_mp_tac envC_tagged_extend >>
      simp[] >>
      PairCases_on`tagenv_st`>>fs[get_tagenv_def] ) >>
    rpt var_eq_tac >>
    fs[s_rel_cases,vs_rel_list_rel] >>
    match_mp_tac EVERY2_APPEND_suff >> fs[] >>
    simp[EVERY2_MAP,OPTREL_def] >> fs[LIST_REL_EL_EQN] >>
    fs[OPTREL_def] >> rw[] >> rfs[] >>
    res_tac >> simp[] >> metis_tac[v_rel_weakening])
  >- (
    first_assum(mp_tac o MATCH_MP compile_decs_correct) >> simp[] >>
    disch_then(mp_tac o REWRITE_RULE[GSYM AND_IMP_INTRO]) >>
    disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >> simp[] >>
    rpt(disch_then(fn th => first_assum(mp_tac o MATCH_MP th))) >>
    strip_tac >>
    first_assum(match_exists_tac o concl) >>
    simp[PULL_EXISTS] >>
    fs[get_exh_def] >>
    conj_tac >- (
      Cases_on`env.c`>> Cases_on`mn`>>
      simp[modSemTheory.mod_cenv_def,modSemTheory.update_mod_state_def,merge_alist_mod_env_def] >>
      fs[] >> rpt var_eq_tac >> fs[SUBSET_DEF] >>
      imp_res_tac modPropsTheory.evaluate_decs_state_const >> fs[]) >>
    imp_res_tac FDOM_compile_decs_exh >>
    fs[get_exh_def] >>
    conj_tac >- (
      imp_res_tac modPropsTheory.evaluate_decs_tids_acc >> fs[] >>
      rw[] >> fs[SUBSET_DEF] >>
      res_tac >> fs[] >>
      fs[modPropsTheory.tids_of_decs_def,MEM_FLAT,MEM_MAP] >>
      fs[modSemTheory.prompt_mods_ok_def,EVERY_MEM] >>
      first_x_assum(qspec_then`d`mp_tac) >>
      simp[] >> BasicProvers.CASE_TAC >> fs[] >>
      rw[] >> fs[MEM_MAP] >>
      Cases_on`mn`>>fs[astTheory.mk_id_def] >> rw[] >>
      Cases_on`ds`>>fsrw_tac[boolSimps.DNF_ss,ARITH_ss][compile_decs_def]>>
      TRY(Cases_on`t`>>fsrw_tac[ARITH_ss][])>>rw[]>>fs[]>>
      fs[LET_THM,compile_decs_def]>>rw[]>>
      fs[modSemTheory.evaluate_decs_def,modSemTheory.evaluate_dec_def,LET_THM] >>
      every_case_tac >> fs[]) >>
    conj_tac >- (
      rw[] >> fs[SUBSET_DEF] >>
      res_tac >- (
        res_tac >>
        Cases_on`mn`>>simp[modSemTheory.update_mod_state_def] >>
        imp_res_tac modPropsTheory.evaluate_decs_state_const >> fs[]) >>
      fs[modPropsTheory.tids_of_decs_def,MEM_FLAT,MEM_MAP,modSemTheory.prompt_mods_ok_def,EVERY_MEM] >>
      first_x_assum(qspec_then`d`mp_tac) >>
      simp[] >> BasicProvers.CASE_TAC >> fs[] >>
      rw[] >> fs[MEM_MAP] >>
      Cases_on`mn`>>fs[astTheory.mk_id_def] >>
      rw[modSemTheory.update_mod_state_def] ) >>
    conj_tac >- (
      fs[cenv_inv_def] >>
      simp[get_tagenv_def] >>
      PairCases_on`tagenv_st`>>fs[get_tagenv_def] >>
      fs[envC_tagged_def] >>
      rw[] >> fs[get_exh_def] >>
      first_x_assum(fn th => first_assum (strip_assume_tac o MATCH_MP th)) >>
      `∀m a. mn = SOME m ⇒ cn ≠ Long m a` by (
        Cases_on`env.c`>>fs[lookup_alist_mod_env_def] >>
        rw[] >> fs[] >>
        spose_not_then strip_assume_tac >> fs[] >>
        every_case_tac >> fs[] >>
        imp_res_tac ALOOKUP_MEM >>
        fs[SUBSET_DEF,MEM_MAP,PULL_EXISTS] >>
        res_tac >> fs[] ) >>
      Cases_on`mn`>>simp[mod_tagenv_def] >> fs[lookup_tag_env_def] >>
      BasicProvers.CASE_TAC >> fs[gtagenv_weak_def]
      >- (
        fs[lookup_tag_flat_def,FLOOKUP_FUNION] >>
        BasicProvers.CASE_TAC >> fs[]
        >- metis_tac[FLOOKUP_SUBMAP] >>
        Cases_on`env.c`>>fs[lookup_alist_mod_env_def]>>
        fs[modSemTheory.prompt_mods_ok_def] >>
        Cases_on`ds`>>fs[compile_decs_def]>>rw[]>>fs[]>>
        Cases_on`t'`>>fsrw_tac[ARITH_ss][]>>
        fs[LET_THM,compile_decs_def] >>
        Cases_on`h`>>fs[]>>rw[]>>fs[]>>
        fs[modSemTheory.evaluate_decs_def,modSemTheory.evaluate_dec_def,LET_THM] >>
        every_case_tac >> fs[])
      >- metis_tac[FLOOKUP_SUBMAP]
      >- metis_tac[FLOOKUP_SUBMAP]
      >- ( simp[FLOOKUP_UPDATE] >> metis_tac[FLOOKUP_SUBMAP])) >>
    rpt var_eq_tac >>
    conj_tac >- (
      fs[s_rel_cases] >>
      imp_res_tac compile_decs_dummy_env_num_defs >>
      match_mp_tac EVERY2_APPEND_suff >> fs[] >>
      reverse conj_tac >- (
        fs[LIST_REL_EL_EQN,vs_rel_list_rel,OPTREL_def] ) >>
      match_mp_tac EVERY2_APPEND_suff >> fs[] >>
      simp[EVERY2_MAP,OPTREL_def] >>
      fs[vs_rel_list_rel,LIST_REL_EL_EQN] >>
      fs[OPTREL_def] >> rw[] >> rfs[] >>
      res_tac >> simp[] >> metis_tac[v_rel_weakening]) >>
    simp[result_rel_cases] >>
    fs[s_rel_cases]))

val compile_prompt_exh_weak = store_thm("compile_prompt_exh_weak",
  ``exh_weak (get_exh st) (get_exh (FST (compile_prompt st pr)))``,
  rw[compile_prompt_def] >>
  every_case_tac >> simp[] >>
  simp[UNCURRY,get_exh_def] >>
  qspecl_then[`l`,`st,FEMPTY`]strip_assume_tac compile_decs_exh_weak >>
  metis_tac[get_exh_def,SND,FST,PAIR])

val compile_prog_exh_weak = store_thm("compile_prog_exh_weak",
  ``∀p st. exh_weak (get_exh st) (get_exh (FST (compile_prog st p)))``,
  Induct >> simp[compile_prog_def] >>
  rw[UNCURRY] >>
  match_mp_tac (GEN_ALL exh_weak_trans) >>
  metis_tac[compile_prompt_exh_weak])

val compile_prog_correct = Q.store_thm ("compile_prog_correct",
  `!env s prog res_tmp.
    evaluate_prompts env s prog = res_tmp ⇒
    !s_i2 next tagenv exh prog_i2 genv' envC' s' res gtagenv next' tagenv' exh'.
    res_tmp = (s', envC', genv', res) ∧
    res ≠ SOME (Rabort Rtype_error) ∧
    invariant env.c (next,tagenv,exh) gtagenv s s_i2 ∧
    no_dup_mods prog s.defined_mods ∧
    no_dup_top_types prog s.defined_types ∧
    EVERY (λp. case p of Prompt mn ds => prompt_mods_ok mn ds) prog ∧
    ((next',tagenv',exh'), prog_i2) = compile_prog (next,tagenv,exh) prog
    ⇒
    ?genv'_i2 s'_i2 res_i2 gtagenv'.
      gtagenv_weak gtagenv gtagenv' ∧
      evaluate_prog <| exh := exh'; v := [] |> s_i2 prog_i2 = (s'_i2,genv'_i2,res_i2) ∧
      (res = NONE ∧ res_i2 = NONE ∧
       invariant (merge_alist_mod_env envC' env.c) (next',tagenv',exh') gtagenv' s' s'_i2 ∨
       ?err err_i2. res = SOME err ∧ res_i2 = SOME err_i2 ∧
         s_rel gtagenv' s' s'_i2 ∧
         result_rel v_rel gtagenv' (Rerr err) (Rerr err_i2))`,
  Induct_on`prog` >>
  rw [modSemTheory.evaluate_prompts_def,compile_prog_def]
  >- (
    rw[conSemTheory.evaluate_prog_def] >>
    metis_tac[gtagenv_weak_refl,cenv_inv_def,invariant_def]) >>
  fs[LET_THM] >>
  first_assum(split_applied_pair_tac o rhs o concl) >> fs [] >>
  first_assum(split_applied_pair_tac o rhs o concl) >> fs [] >>
  rw [] >>
  Cases_on`h`>>fs[] >>
  first_assum(split_pair_case_tac o lhs o concl) >> fs[] >>
  (compile_prompt_correct |> REWRITE_RULE[GSYM AND_IMP_INTRO]
    |> (fn th => first_assum (mp_tac o MATCH_MP th))) >>
  simp[GSYM PULL_FORALL] >>
  discharge_hyps >- (strip_tac >> fs[]) >>
  disch_then(fn th => first_assum(mp_tac o MATCH_MP th)) >> simp[] >>
  reverse strip_tac >> rpt var_eq_tac >> fs[] >> rpt var_eq_tac >- (
    simp[conSemTheory.evaluate_prog_def] >>
    imp_res_tac evaluate_prompt_exh_weak >> fs[] >>
    first_x_assum(fn th => mp_tac th >> (discharge_hyps >- (strip_tac >> fs[result_rel_cases]))) >>
    disch_then(qspec_then`exh'`mp_tac) >>
    discharge_hyps >- (
      metis_tac[compile_prog_exh_weak,FST,get_exh_def] ) >>
    rw[] >>
    first_assum(match_exists_tac o concl) >> rw[] ) >>
  first_assum(split_pair_case_tac o lhs o concl) >> fs[] >>
  rpt var_eq_tac >>
  first_x_assum(fn th => first_assum(mp_tac o MATCH_MP(ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >> simp[] >>
  CONV_TAC(LAND_CONV(STRIP_QUANT_CONV(LAND_CONV(lift_conjunct_conv is_eq)))) >>
  ONCE_REWRITE_TAC[GSYM AND_IMP_INTRO] >>
  `∃a b c. st' = (a,b,c)` by metis_tac[PAIR] >> var_eq_tac >>
  disch_then(fn th => first_assum(mp_tac o MATCH_MP th o SYM)) >>
  CONV_TAC(LAND_CONV(STRIP_QUANT_CONV(LAND_CONV(lift_conjunct_conv (same_const``invariant`` o fst o strip_comb))))) >>
  disch_then drule >>
  discharge_hyps >- (
    fs [modPropsTheory.no_dup_mods_eqn, modPropsTheory.no_dup_top_types_eqn] >>
    imp_res_tac modPropsTheory.evaluate_prompt_mods_disjoint >> fs[] >>
    imp_res_tac modPropsTheory.evaluate_prompt_tids >> fs[] >>
    reverse conj_tac >- (
      fs[modSemTheory.no_dup_mods_def,modSemTheory.evaluate_prompt_def,LET_THM] >>
      BasicProvers.FULL_CASE_TAC >> fs[] >>
      first_assum(split_applied_pair_tac o lhs o concl) >> fs [] >> fs[] >>
      rpt var_eq_tac >> fs[] >>
      fs[modSemTheory.update_mod_state_def] >>
      imp_res_tac modPropsTheory.evaluate_decs_state_const >> fs[] >>
      BasicProvers.CASE_TAC >> fs[DISJOINT_SYM] ) >>
    fs[modSemTheory.no_dup_top_types_def] >>
    fs[modPropsTheory.tids_of_prompt_def,IN_DISJOINT,MEM_MAP,EXTENSION] >>
    spose_not_then strip_assume_tac >> rw[] >>
    first_x_assum(qspec_then`(Short tn)`mp_tac) >> simp[] >>
    reverse conj_tac >- metis_tac[] >>
    rator_x_assum`prompt_mods_ok`mp_tac >>
    simp[modSemTheory.prompt_mods_ok_def] >>
    BasicProvers.CASE_TAC >> fs[] >- (
      simp[modPropsTheory.tids_of_decs_def,MEM_FLAT,MEM_MAP,PULL_EXISTS,PULL_FORALL] >>
      gen_tac >> strip_tac >>
      every_case_tac >> fs[] >> fs[MEM_MAP] >> rw[] >>
      spose_not_then strip_assume_tac >>
      qmatch_assum_rename_tac`MEM (Dtype mno tds) decs` >>
      Cases_on`mno`>>fs[astTheory.mk_id_def]>>
      var_eq_tac >>
      Cases_on`decs`>>fs[]>>Cases_on`t`>>fsrw_tac[ARITH_ss][]>>
      var_eq_tac >> fs[modSemTheory.decs_to_types_def,MEM_MAP,UNCURRY] >>
      metis_tac[] ) >>
    simp[EVERY_MEM] >>
    simp[modPropsTheory.tids_of_decs_def,MEM_FLAT,MEM_MAP,PULL_EXISTS] >> rw[] >>
    every_case_tac >> fs[] >>
    spose_not_then strip_assume_tac >>
    res_tac >> fs[astTheory.mk_id_def,MEM_MAP] ) >>
  reverse strip_tac >- (
    rpt var_eq_tac >> simp[] >>
    simp[conSemTheory.evaluate_prog_def] >>
    imp_res_tac evaluate_prompt_exh_weak >> fs[] >>
    first_x_assum(qspec_then`exh'`mp_tac) >>
    discharge_hyps >- (
      metis_tac[compile_prog_exh_weak,FST,get_exh_def] ) >>
    rw[] >>
    metis_tac[gtagenv_weak_trans] ) >>
  rpt var_eq_tac >> simp[] >>
  imp_res_tac evaluate_prompt_exh_weak >> fs[] >>
  first_x_assum(qspec_then`exh'`mp_tac) >>
  discharge_hyps >- (
    metis_tac[compile_prog_exh_weak,FST,get_exh_def] ) >>
  rw[conSemTheory.evaluate_prog_def] >>
  fs[merge_alist_mod_env_assoc] >>
  metis_tac[gtagenv_weak_trans]);

val compile_prog_evaluate = Q.store_thm ("compile_prog_evaluate",
  `!env s prog s_i2 next tagenv exh prog_i2 s' res gtagenv next' tagenv' exh'.
    evaluate_prog env s prog = (s',res) ∧
    res ≠ SOME (Rabort Rtype_error) ∧
    invariant env.c (next,tagenv,exh) gtagenv s s_i2 ∧
    ((next',tagenv',exh'), prog_i2) = compile_prog (next,tagenv,exh) prog
    ⇒
    ?genv'_i2 s'_i2 res_i2 gtagenv'.
      gtagenv_weak gtagenv gtagenv' ∧
      evaluate_prog <| exh := exh'; v := [] |> s_i2 prog_i2 = (s'_i2,genv'_i2,res_i2) ∧
      OPTION_REL (CURRY (UNCURRY (result_rel v_rel gtagenv') o (Rerr ## Rerr))) res res_i2 ∧
      s_rel gtagenv' s' s'_i2`,
  rw [modSemTheory.evaluate_prog_def,LET_THM] >>
  first_assum(split_applied_pair_tac o lhs o concl) >> fs[] >>
  first_x_assum(mp_tac o MATCH_MP compile_prog_correct) >> simp[] >>
  disch_then(fn th => (first_assum (mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO]th)))) >>
  disch_then(fn th => (first_assum (mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO]th)))) >> rw[] >>
  fs[invariant_def,OPTREL_def] >> metis_tac[]);

val compile_prog_semantics = Q.store_thm("compile_prog_semantics",
  `semantics env s prog ≠ Fail ⇒
   invariant env.c tagenv_st gtagenv s s_i2 ⇒
   compile_prog tagenv_st prog = (tagenv_st', prog_i2) ⇒
   semantics <| exh := get_exh tagenv_st'; v := [] |> s_i2 prog_i2
     = semantics env s prog`,
  simp[modSemTheory.semantics_def] >>
  IF_CASES_TAC >> fs[] >>
  DEEP_INTRO_TAC some_intro >> simp[] >>
  conj_tac >- (
    rw[] >>
    simp[conSemTheory.semantics_def] >>
    IF_CASES_TAC >> fs[] >- (
      rator_x_assum`modSem$evaluate_prog`kall_tac >>
      last_x_assum(qspec_then`k'`mp_tac)>>simp[] >>
      (fn g => subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) (#2 g) g) >>
      spose_not_then strip_assume_tac >> fs[] >>
      drule compile_prog_evaluate >>
      disch_then drule >>
      imp_res_tac invariant_with_clock >>
      pop_assum(qspec_then`k'`strip_assume_tac) >>
      PairCases_on`tagenv_st`>>
      disch_then drule >>
      PairCases_on`tagenv_st'` >>
      simp[] >>
      spose_not_then strip_assume_tac >>
      fs[get_exh_def] >> rveq >> fs[OPTREL_def] >>
      fs[result_rel_cases]) >>
    DEEP_INTRO_TAC some_intro >> simp[] >>
    conj_tac >- (
      rw[] >>
      qmatch_assum_abbrev_tac`modSem$evaluate_prog env ss es = _` >>
      qmatch_assum_abbrev_tac`conSem$evaluate_prog bnv bs be = _` >>
      qispl_then[`env`,`ss`,`es`]mp_tac modPropsTheory.evaluate_prog_add_to_clock_io_events_mono >>
      qispl_then[`bnv`,`bs`,`be`]mp_tac conPropsTheory.evaluate_prog_add_to_clock_io_events_mono >>
      simp[Abbr`bs`,Abbr`ss`] >>
      disch_then(qspec_then`k`strip_assume_tac) >>
      disch_then(qspec_then`k'`strip_assume_tac) >>
      Cases_on`s'.ffi.final_event`>>fs[]>-(
        Cases_on`s''.ffi.final_event`>>fs[]>-(
          unabbrev_all_tac >>
          drule compile_prog_evaluate >>
          imp_res_tac invariant_with_clock >>
          pop_assum(qspec_then`k`strip_assume_tac) >>
          simp[] >>
          PairCases_on`tagenv_st`>>
          disch_then drule >>
          PairCases_on`tagenv_st'` >>
          simp[] >>
          strip_tac >>
          drule (GEN_ALL conPropsTheory.evaluate_prog_add_to_clock) >>
          simp[RIGHT_FORALL_IMP_THM] >>
          discharge_hyps >- (strip_tac >> fs[OPTREL_def,result_rel_cases]) >>
          disch_then(qspec_then`k'`mp_tac)>>simp[]>>
          rator_x_assum`conSem$evaluate_prog`mp_tac >>
          drule (GEN_ALL conPropsTheory.evaluate_prog_add_to_clock) >>
          simp[] >>
          disch_then(qspec_then`k`mp_tac)>>simp[]>>
          ntac 3 strip_tac >> rveq >> fs[] >>
          fsrw_tac[ARITH_ss][get_exh_def] >>
          fs[conSemTheory.state_component_equality,OPTREL_def,result_rel_cases,s_rel_cases] >> rfs[]) >>
        first_assum(subterm (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl) >> fs[] >>
        unabbrev_all_tac >>
        drule compile_prog_evaluate >>
        CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[RIGHT_FORALL_IMP_THM,GSYM AND_IMP_INTRO])) >>
        discharge_hyps >- (
          last_x_assum(qspec_then`k+k'`mp_tac)>>
          fsrw_tac[ARITH_ss][]) >>
        imp_res_tac invariant_with_clock >>
        pop_assum(qspec_then`k'+k`strip_assume_tac) >>
        PairCases_on`tagenv_st`>>
        disch_then drule >>
        PairCases_on`tagenv_st'` >>
        simp[] >> spose_not_then strip_assume_tac >>
        rator_x_assum`modSem$evaluate_prog`mp_tac >>
        drule (GEN_ALL modPropsTheory.evaluate_prog_add_to_clock) >>
        CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[RIGHT_FORALL_IMP_THM])) >>
        discharge_hyps >- (strip_tac >> fs[]) >>
        disch_then(qspec_then`k'`mp_tac)>>simp[] >>
        strip_tac >>
        spose_not_then strip_assume_tac >>
        rveq >>
        fsrw_tac[ARITH_ss][s_rel_cases,get_exh_def] >> rfs[]) >>
      first_assum(subterm (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl) >> fs[] >>
      unabbrev_all_tac >>
      drule compile_prog_evaluate >>
      CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[RIGHT_FORALL_IMP_THM,GSYM AND_IMP_INTRO])) >>
      discharge_hyps >- (
        last_x_assum(qspec_then`k+k'`mp_tac)>>
        fsrw_tac[ARITH_ss][]) >>
      imp_res_tac invariant_with_clock >>
      pop_assum(qspec_then`k'+k`strip_assume_tac) >>
      PairCases_on`tagenv_st`>>
      disch_then drule >>
      PairCases_on`tagenv_st'` >>
      simp[] >> strip_tac >>
      fs[] >> rveq >>
      reverse(Cases_on`s''.ffi.final_event`)>>fs[]>>rfs[]>- (
        fsrw_tac[ARITH_ss][get_exh_def] >> fs[s_rel_cases] >> rfs[]) >>
      rator_x_assum`conSem$evaluate_prog`mp_tac >>
      drule (GEN_ALL conPropsTheory.evaluate_prog_add_to_clock) >>
      CONV_TAC(LAND_CONV(SIMP_CONV(srw_ss())[RIGHT_FORALL_IMP_THM])) >>
      discharge_hyps >- fs[] >>
      disch_then(qspec_then`k`mp_tac)>>simp[] >>
      rpt strip_tac >> spose_not_then strip_assume_tac >> rveq >>
      fsrw_tac[ARITH_ss][get_exh_def,s_rel_cases,conSemTheory.state_component_equality] >>
      rfs[]) >>
    drule compile_prog_evaluate >> simp[] >>
    simp[RIGHT_FORALL_IMP_THM,GSYM AND_IMP_INTRO] >>
    last_x_assum(qspec_then`k`strip_assume_tac) >> rfs[] >>
    imp_res_tac invariant_with_clock >>
    pop_assum(qspec_then`k`strip_assume_tac) >>
    PairCases_on`tagenv_st`>>
    disch_then drule >>
    PairCases_on`tagenv_st'` >>
    simp[] >> strip_tac >>
    simp[get_exh_def] >>
    asm_exists_tac >> simp[] >>
    fs[s_rel_cases] >>
    CASE_TAC >> fs[] >>
    spose_not_then strip_assume_tac >>
    fs[OPTREL_def,result_rel_cases]) >>
  rw[] >>
  simp[conSemTheory.semantics_def] >>
  IF_CASES_TAC >> fs[] >- (
    last_x_assum(qspec_then`k`strip_assume_tac) >>
    qmatch_assum_abbrev_tac`(SND q) ≠ _` >>
    PairCases_on`q`>>fs[markerTheory.Abbrev_def] >>
    pop_assum(assume_tac o SYM) >>
    first_assum(mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO]compile_prog_evaluate)) >>
    simp[] >>
    PairCases_on`tagenv_st` >>
    imp_res_tac invariant_with_clock >>
    first_x_assum(qspec_then`k`strip_assume_tac) >>
    first_assum(match_exists_tac o concl) >> simp[] >>
    PairCases_on`tagenv_st'`>>fs[] >> fs[get_exh_def] >>
    spose_not_then strip_assume_tac >> fs[] >>
    rfs[OPTREL_def] >> fs[result_rel_cases]) >>
  DEEP_INTRO_TAC some_intro >> simp[] >>
  conj_tac >- (
    spose_not_then strip_assume_tac >>
    last_x_assum(qspec_then`k`mp_tac) >>
    (fn g => subterm (fn tm => Cases_on`^(assert has_pair_type tm)` g) (#2 g)) >>
    spose_not_then strip_assume_tac >> fs[] >>
    last_x_assum(qspec_then`k`mp_tac)>>simp[]>>
    drule compile_prog_evaluate >>
    imp_res_tac invariant_with_clock >>
    pop_assum(qspec_then`k`strip_assume_tac) >>
    PairCases_on`tagenv_st`>>
    disch_then drule >>
    disch_then drule >>
    PairCases_on`tagenv_st'` >>
    simp[] >> strip_tac >>
    fs[get_exh_def] >>
    fs[s_rel_cases] >>
    CASE_TAC >> fs[] >>
    spose_not_then strip_assume_tac >>
    fs[OPTREL_def,result_rel_cases]) >>
  rpt strip_tac >>
  rpt (AP_TERM_TAC ORELSE AP_THM_TAC) >>
  simp[FUN_EQ_THM] >> gen_tac >>
  rpt (AP_TERM_TAC ORELSE AP_THM_TAC) >>
  qmatch_abbrev_tac`_ = _ (FST q)` >>
  PairCases_on`q`>>fs[markerTheory.Abbrev_def] >>
  pop_assum(mp_tac o SYM) >>
  specl_args_of_then``modSem$evaluate_prog``compile_prog_evaluate mp_tac >>
  CONV_TAC(LAND_CONV(STRIP_QUANT_CONV(LAND_CONV(lift_conjunct_conv(same_const``invariant`` o fst o strip_comb))))) >>
  PairCases_on`tagenv_st` >>
  imp_res_tac invariant_with_clock >>
  first_x_assum(qspec_then`k`strip_assume_tac) >>
  disch_then(fn th => first_assum (mp_tac o MATCH_MP (ONCE_REWRITE_RULE[GSYM AND_IMP_INTRO]th))) >>
  simp[] >>
  PairCases_on`tagenv_st'`>>fs[] >> fs[get_exh_def] >>
  rw[] >> fs[] >>
  first_assum(fn th => mp_tac th >> discharge_hyps >- metis_tac[SND]) >>
  strip_tac >> simp[] >> fs[s_rel_cases]);

val prog_to_top_types_def = modSemTheory.prog_to_top_types_def;
val decs_to_types_def = modSemTheory.decs_to_types_def;
val prompt_mods_ok_def = modSemTheory.prompt_mods_ok_def;

val alloc_tags_exh_unchanged = Q.store_thm("alloc_tags_exh_unchanged",
  `∀c b a.
    ¬MEM (Short t) (MAP (λ(tvs,tn,ctors). mk_id a tn) c) ∧
    FLOOKUP (get_exh(FST b)) (Short t) = SOME v ⇒
    FLOOKUP (get_exh(FST(alloc_tags a b c))) (Short t) = SOME v`,
  Induct >> simp[alloc_tags_def] >>
  rw[] >> PairCases_on`h` >>
  simp[alloc_tags_def] >>
  first_x_assum match_mp_tac >> fs[] >>
  pop_assum mp_tac >>
  qid_spec_tac`b` >>
  Induct_on`h2`>>rw[] >>
  simp[UNCURRY] >>
  first_x_assum match_mp_tac >>
  PairCases_on`b` >>
  simp[alloc_tag_def] >>
  every_case_tac >> fs[get_exh_def] >>
  simp[FLOOKUP_UPDATE]);

val compile_decs_exh_unchanged = Q.store_thm("compile_decs_exh_unchanged",
  `∀ds a st sta st' ac b.
   EVERY (λd. case d of Dtype mn _ => mn = SOME x | Dexn mn _ _ => mn = SOME x | _ => T) ds ∧
   compile_decs sta ds = ((st',ac),b) ∧ st = FST sta ∧
   FLOOKUP (get_exh st) (Short t) = SOME v
   ⇒
   FLOOKUP (get_exh st') (Short t) = SOME v`,
  Induct >> simp[compile_decs_def] >> rw[] >> fs[] >>
  every_case_tac >> fs[] >>
  split_pair_tac >> fs[] >> rveq >>
  res_tac >> fs[] >>
  pop_assum kall_tac >>
  first_x_assum match_mp_tac >- (
    match_mp_tac alloc_tags_exh_unchanged >>
    simp[MEM_MAP,UNCURRY,astTheory.mk_id_def] ) >>
  PairCases_on`sta`>>simp[alloc_tag_def] >>
  fs[get_exh_def]);

val compile_prompt_exh_unchanged = Q.store_thm("compile_prompt_exh_unchanged",
  `(∀ds. p = Prompt NONE ds ⇒ ¬MEM t (decs_to_types ds)) ∧
   (∀mn ds. p = Prompt mn ds ⇒ prompt_mods_ok mn ds) ∧
   FLOOKUP (get_exh st) (Short t) = SOME v ⇒
   FLOOKUP (get_exh (FST (compile_prompt st p))) (Short t) = SOME v`,
  rw[compile_prompt_def] >>
  BasicProvers.TOP_CASE_TAC >> rw[] >> rw[get_exh_def] >>
  fs[prompt_mods_ok_def] >>
  every_case_tac >> fs[] >- (
    Cases_on`l`>>fs[compile_decs_def] >> rveq >- fs[get_exh_def] >>
    Cases_on`t'`>>fsrw_tac[ARITH_ss][]>>
    every_case_tac >> fs[LET_THM] >>
    split_pair_tac >> fs[] >> rveq >>
    fs[compile_decs_def] >> rveq >> fs[get_exh_def] >>
    PairCases_on`st`>>
    fs[decs_to_types_def,alloc_tag_def,LET_THM] >>
    rveq >> fs[get_exh_def] >> rw[] >>
    qmatch_assum_abbrev_tac`alloc_tags a b c = _` >>
    qispl_then[`c`,`b`,`a`]mp_tac alloc_tags_exh_unchanged >>
    simp[get_exh_def] >> disch_then match_mp_tac >>
    simp[Abbr`b`,get_exh_def,MEM_MAP,UNCURRY] >>
    Cases_on`a`>>simp[astTheory.mk_id_def,FORALL_PROD] >>
    fs[MEM_MAP,EXISTS_PROD] ) >>
  imp_res_tac compile_decs_exh_unchanged >> fs[get_exh_def]);

val compile_prog_exh_unchanged = Q.store_thm("compile_prog_exh_unchanged",
  `∀p st.
   ¬MEM t (prog_to_top_types p) ∧
   EVERY (λp. case p of Prompt mn ds => prompt_mods_ok mn ds) p ∧
   FLOOKUP (get_exh st) (Short t) = SOME v ∧
   exh' = get_exh (FST (compile_prog st p))
   ⇒
   FLOOKUP exh' (Short t) = SOME v`,
  Induct >> simp[compile_prog_def] >> rw[UNCURRY] >>
  `¬MEM t (prog_to_top_types p)` by (
    fs[prog_to_top_types_def] ) >> fs[] >>
  first_x_assum match_mp_tac >>
  fs[prog_to_top_types_def] >>
  match_mp_tac compile_prompt_exh_unchanged >>
  Cases_on`h`>>fs[]>>rw[]>>fs[]);

val _ = export_theory ();