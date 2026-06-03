# Adapter Contract

## Device Families

Recommended names:

- synchronous generator: `SG_<bus>` or `G<bus>`
- DFIG: `DFIG_W<bus>` or `DFIG_W<bus>_<unit>`
- VSC: `VSC_<id>`
- MMC: `MMC_<id>`
- LCC: `LCC_REC` / `LCC_INV`
- storage: `BESS_<id>`
- load: `Load_<bus>` or `RLC_Load_<bus>`
- line: `Line_<from>_<to>` or `TieLine_<id>`
- transformer: `Transformer_<from>_<to>` or `Xfmr_<id>`

## Required Build-Script Practices

1. Copy whole working donor subsystems when a device is complex.
2. Introspect mask names before `set_param` on masked SPS blocks.
3. Wire physical SPS ports explicitly with `RConn/LConn`; never replace them
   with Goto/From.
4. Use Goto/From only for ordinary signals such as `Utabc`, `Itabc`,
   `WindSpeed`, `Pref`, `Qref`, `Vref`.
5. Set model InitFcn with donor aliases such as `Ts` and `Tsample`.
6. Attach trace metadata where practical:

```matlab
trace = struct();
trace.id = "dfig_W33_a";
trace.component_type = "dfig_wind";
trace.source_spec = "specs/case_model.yaml";
trace.source_section = "topology.unit_a";
trace.template = "ieee39_10m39bus_sg5_dfig5_nebus_layout/W33";
set_param(blockPath, "UserData", trace);
set_param(blockPath, "UserDataPersistent", "on");
```

## Inspection

Run `inspect_device_adapter_contract` after build. Missing trace metadata is a
warning by default and can become a hard failure by passing `StrictTrace=true`.
The helper inspects root-level device subsystems and key SPS blocks, so it can
catch adapter issues on copied SG/DFIG/VSC/MMC/LCC subsystems as well as
root-level loads, lines, and transformers.
