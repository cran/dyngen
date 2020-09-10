# dyngen 0.4.0 (2020-07-15)

## MAJOR CHANGES:

* `wrap_dataset()`: Outputted `$counts` now contains counts of both spliced and unspliced reads, whereas
  `$counts_unspliced` and `$counts_spliced` contains separated counts.
  
* Added a docker container containing the necessary code to run a dyngen simulation.
  
## MINOR CHANGES:

* Added logo to package.

* Clean up internal code, mostly to satisfy R CMD check.

## DOCUMENTATION:

* Added two vignettes.

* Expanded the README.

# dyngen 0.3.0 (2020-04-06)

## NEW FEATURES:

* Implement knockdown / knockouts / overexpression experiments.

* Implement better single-cell regulatory activity by determining
  the effect on propensity values after knocking out a transcription factor.
  
* Implement adding noise to the kinetic params of individual simulations.

* Kinetics (transcription rate, translation rate, decay rate, ...) are 
  based on Schwannhausser et al. 2011.

* Changed many parameter names to better explain its purpose.

## MINOR CHANGES:

* Fix module naming of backbones derived from `backbone_branching()`.

* Allow to plot labels in `plot_simulation_expression()`.

* Improve `backbone_disconnected()` and `backbone_converging()`.

* Rename required columns in `backbone()` input data.

* Use `backbone_linear()` to make `backbone_cyclic()` randomised.

* Added a decay rate for pre-mRNAs as well.

* Kinetics: redefine the decay rates in terms of the half-life of these molecules.

* Only compute dimred if desired.

* Allow computing the propensity ratios as ground-truth for rna velocity.

## BUG FIXES:

* Implement fix for double positives in `bblego` backbones.

* Fix graph plotting mixup of interaction effects (up/down).

* Made a fix to the computation of `feature_info$max_protein`.


# dyngen 0.2.1 (2019-07-17)

* MAJOR CHANGES: Custom backbones can be defined using backbone lego pieces. See `?bblego` for more information.

* MAJOR CHANGES: Splicing reactions have been reworked to better reflect biology.

# dyngen 0.2.0 (2019-07-12)

Complete rewrite from `dyngen` from the bottom up.
 
* OPTIMISATION: All aspects of the pipeline have been optimised towards execution time and end-user usability.

* OPTIMISATION: `dyngen` 0.2.0 uses `gillespie` 0.2.0, which has also been rewritten entirely in `Rcpp`,
  thereby improving the speed significantly.
  
* OPTIMISATION: The transcription factor propensity functions have been refactored to make it much more 
  computationally efficient.
  
* OPTIMISATION: Mapping a simulation to the gold standard is more automised and less error-prone.

* FEATURE: A splicing step has been added to the chain of reaction events.

# dyngen 0.1.0 (2017-04-27)

 * INITIAL RELEASE: a package for generating synthetic single-cell data from regulatory networks.
   Key features are:
   
   - The cells undergo a dynamic process throughout the simulation.
   - Many different trajectory types are supported.
   - `dyngen` 0.1.0 uses `gillespie` 0.1.0, a clone of `GillespieSSA` that is much less
     error-prone and more efficient than `GillespieSSA`.

# dyngen 0.0.1 (2016-04-04)

 * Just a bunch of scripts on a repository, which creates random networks using `igraph` and 
   generates simple single-cell expression data using `GillespieSSA`.
